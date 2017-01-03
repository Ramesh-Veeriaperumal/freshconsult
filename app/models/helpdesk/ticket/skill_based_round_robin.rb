class Helpdesk::Ticket < ActiveRecord::Base

  def enqueue_skill_based_round_robin
    Rails.logger.debug "Inspecting SBRR job enqueue source for ticket #{display_id} \n #{caller.join("\n")}"
    SBRR::Assignment.perform_async(:model_changes => model_changes, 
      :ticket_id => display_id, :attributes => { :sbrr_fresh_ticket => sbrr_fresh_ticket,
      :sbrr_ticket_dequeued => sbrr_ticket_dequeued, 
      :sbrr_user_score_incremented => sbrr_user_score_incremented })
  end

  def enqueue_sbrr_job?
    SBRR.log "Ticket ##{self.display_id} Enqueue SBRR job? #{right_time_to_enqueue_sbrr_job?} && #{should_enqueue_sbrr_job?}" 
    right_time_to_enqueue_sbrr_job? && should_enqueue_sbrr_job?
  end

  def should_enqueue_sbrr_job?
    remap_skill? || has_queue_changes?
  end

  def map_skill
    if remap_skill?
      Admin::Skill.map_to self
      merge_skill_change_to_model_changes
    end
  end

  def remap_skill?
    eligible_for_round_robin? && unassigned?
  end

  def has_ticket_queue_changes?
    has_user_queue_changes? || @model_changes.key?(skill_id_column)
  end
  alias_method :has_queue_changes?, :has_ticket_queue_changes?

  def has_user_queue_changes?
    has_round_robin_eligibility_changes? || @model_changes.key?(:responder_id) || sbrr_fresh_ticket
  end

  def has_round_robin_eligibility_changes?
    @model_changes.key?(:group_id) || stop_sla_timer_changed? || visibility_changed?
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

  private    

    def right_time_to_enqueue_sbrr_job?
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
      if schema_less_ticket.changes.key?(skill_id_column)
        @model_changes = merge_changes @model_changes, schema_less_ticket.changes
      end
    end

    def eligible_for_round_robin?
      visible? && !(ticket_status.stop_sla_timer) && 
        group.present? && group.skill_based_round_robin_enabled? 
    end

    def agent_available?
      assigned? && responder && responder.available?
    end

    def unassigned?
      !assigned?
    end

    def assigned?
      responder_id.present?
    end
    
end
