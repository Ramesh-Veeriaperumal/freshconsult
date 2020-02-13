class Helpdesk::Ticket < ActiveRecord::Base

  def enqueue_skill_based_round_robin
    Rails.logger.debug "Inspecting SBRR job enqueue source for ticket #{display_id}, sbrr inline #{sbrr_inline?} \n #{caller.join("\n")}"
    options = skip_sbrr_assigner ? {:action => "update_multiple_sync"} : {}
    args = { :model_changes => sbrr_model_changes, :ticket_id => display_id, :skip_skill_remap => ticket_update_skill_alone?, 
      :attributes => sbrr_attributes, :sbrr_state_attributes => sbrr_state_attributes, :options => options, :parent_jid => Thread.current[:message_uuid] }
    if sbrr_inline?
      @sbrr_exec_obj = SBRR::Execution.new(args)
      @sbrr_exec_obj.execute
    else
      SBRR::Assignment.perform_async(args)
    end
  end

  def enqueue_sbrr_job?
    SBRR.log "Ticket ##{self.display_id} Enqueue SBRR job? #{right_time_to_enqueue_sbrr_job?} && #{should_enqueue_sbrr_job?}" 
    right_time_to_enqueue_sbrr_job? && should_enqueue_sbrr_job?
  end

  def should_enqueue_sbrr_job?
    SBRR.log "remap_skill: #{remap_skill.inspect} has_queue_changes?: #{has_queue_changes?.inspect}
              sbrr_enabled?: #{sbrr_enabled?.inspect}"
    (remap_skill? || has_queue_changes?) && sbrr_enabled?
  end

  def map_skill
    if remap_skill?
      Admin::Skill.map_to self
      merge_skill_change_to_model_changes
      set_sbrr_skill_activity
    end
  end

  def remap_skill?
    eligible_for_round_robin? && unassigned?
  end

  def ticket_update_skill_alone?
    model_changes.key?(skill_id_column) && skill_condition_changes_empty?
  end

  def skill_condition_changes_empty?
    model_changes.slice(*skill_condition_attributes).empty?
  end

  def has_ticket_queue_changes?
    has_user_queue_changes? || model_changes.key?(skill_id_column)
  end
  alias_method :has_queue_changes?, :has_ticket_queue_changes?

  def has_user_queue_changes?
    #has_config_changes? has to be before has_round_robin_eligibility_changes? for ticket status delete case
    has_config_changes? || has_round_robin_eligibility_changes? || model_changes.key?(:responder_id)
  end

  def has_round_robin_eligibility_changes?
    model_changes.key?(:group_id) || stop_sla_timer_changed? || visibility_changed?
  end

  def has_config_changes?
    sbrr_fresh_ticket || sbrr_turned_on || status_sla_toggled_to
  end

  def can_be_in_ticket_queue?
    eligible_for_round_robin? && unassigned? && skill.present?
  end

  def can_account_for_user_score?
    eligible_for_round_robin? && assigned? && agent_available? &&
      group.has_agent?(responder)
  end

  def match_sbrr_conditions?(_user)
    AgentGroup.exists?(:user_id => _user.id, :group_id => self.group_id) &&
      UserSkill.exists?(:user_id => _user.id, :skill_id => self.skill_id) &&
        _user.agent.available
  end

  def merge_changes _previous_changes, _current_changes
    _previous_changes = (_previous_changes || {}).to_hash.symbolize_keys
    _current_changes  = (_current_changes  || {}).to_hash.symbolize_keys
    _previous_changes.merge!(_current_changes) do |key, v1, v2| 
      if v1.present? && v2.present?
        [v1.first, v2.last] if v1.first != v2.last
      elsif v1.present?
        v1 if v1.first != v1.last
      else
        v2 if v2.first != v2.last
      end
    end
    _previous_changes.reject{|_attribute, _change| _change.nil?}
  end

  def unassigned?
    !assigned?
  end

  def assigned?
    responder_id.present?
  end

  def old_replicated_state?
    replicated_state == TicketConstants::TICKET_REPLICA[:first]
  end

  def new_replicated_state?
    replicated_state == TicketConstants::TICKET_REPLICA[:last]
  end

  def status_sla_toggled_to_on?
    status_sla_toggled_to == :on
  end

  def status_sla_toggled_to_off?
    status_sla_toggled_to == :off
  end

  def eligible_for_round_robin?
    visible? && sla_on? && 
      group.present? && group.skill_based_round_robin_enabled? 
  end

  def sbrr_model_changes
    model_changes.symbolize_keys.slice(*TicketConstants::NEEDED_SBRR_ATTRIBUTES)
  end

  def sbrr_attributes
    attrs = {}
    TicketConstants::SKILL_BASED_TICKET_ATTRIBUTES.each { |att| attrs[att] = safe_send(att) }
    attrs
  end

  private   

    def update_count_for_skill
      self.sbrr_fresh_ticket = true
      enqueue_skill_based_round_robin if Account.current.skill_based_round_robin_enabled?
    end 

    def sbrr_inline?
      Account.current.skill_based_round_robin_enabled? && bg_jobs_inline
    end

    def right_time_to_enqueue_sbrr_job?
      SBRR.log "sbrr_enabled?: #{Account.current.skill_based_round_robin_enabled?.inspect}
                disable_obs_rule: #{disable_observer_rule.inspect}
                obs_not_enqd: #{observer_will_not_be_enqueued?}
                skip_sbrr: #{skip_sbrr.inspect} obs_doer_id: #{Thread.current[:observer_doer_id].inspect}
                skip_rr: #{Thread.current[:skip_round_robin].inspect}
                sbrr_thread: #{Thread.current[:skill_based_round_robin_thread].inspect}
                sbrr_tkt_deqd: #{sbrr_ticket_dequeued.inspect}
                sbrr_usr_scr_incr: #{sbrr_user_score_incremented.inspect}"
      Account.current.skill_based_round_robin_enabled? && 
        disable_observer_rule.nil? && observer_will_not_be_enqueued? && !skip_sbrr &&
          Thread.current[:observer_doer_id].nil? &&
            Thread.current[:skip_round_robin].nil? && 
              Thread.current[:skill_based_round_robin_thread].nil? &&
                !(self.sbrr_ticket_dequeued && self.sbrr_user_score_incremented) #preventing enqueue if queues are handled
    end

    def observer_will_not_be_enqueued?
      (!user_present? || !filter_observer_events(false).present?)
    end

    def merge_skill_change_to_model_changes
      if self.changes.key?(skill_id_column)
        @model_changes = merge_changes model_changes, self.changes
      end
    end

    def sla_on?
      if old_replicated_state? && status_sla_toggled_to_on?
        false
      elsif old_replicated_state? && status_sla_toggled_to_off?
        true
      else
        !ticket_status.stop_sla_timer
      end
    end

    def agent_available?
      assigned? && responder && responder.available?
    end 

    def sbrr_enabled?
      (group.present? && group.skill_based_round_robin_enabled?) || (model_changes.key?(:group_id) && model_changes[:group_id][0].present? && old_group_has_sbrr?)
    end

    def old_group_has_sbrr?
      _group = Account.current.groups.find_by_id model_changes[:group_id][0]
      _group.present? && _group.skill_based_round_robin_enabled? 
    end

end
