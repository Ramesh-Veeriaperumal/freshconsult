class Helpdesk::Ticket < ActiveRecord::Base

  #To be removed after dispatcher redis check removed
  def assign_tickets_to_agents
    #Ticket already has an agent assigned to it or doesn't have a group
    return if group.nil?
    if self.responder_id
      update_capping_on_create
      return
    end
    if group.round_robin_enabled?
      assign_agent_via_round_robin 
      self.save
    end
  end 
  
  #user changes will be passed when observer worker calls the function
  def round_robin_on_ticket_update(user_changes={})
    ticket_changes = self.changes
    ticket_changes  = merge_changes(user_changes,self.changes) if user_changes.present?
    
    if group.round_robin_capping_enabled?
      check_capping_conditions(ticket_changes)
    elsif round_robin_conditions(ticket_changes)
      assign_agent_via_round_robin
    end
  end
  
  def assign_agent_via_round_robin
    return unless group.present?
    next_agent = if group.round_robin_capping_enabled?
      if capping_ready?
        self.round_robin_assignment = true
        group.next_agent_with_capping(self.display_id)
      end
    elsif group.round_robin_enabled?
      agent = group.next_available_agent
      Rails.logger.debug "Normal round robin : #{self.display_id} #{agent.inspect}
        #{get_others_redis_list(group.round_robin_key).inspect}".squish
      agent
    end

    return if next_agent.nil? #There is no agent available to assign ticket.
    self.round_robin_assignment = true
    self.responder_id           = next_agent.user_id
    self.set_round_robin_activity
  end  

  def check_capping_conditions(ticket_changes)
    return if ticket_changes.has_key?(:round_robin_assignment)
    actions = []
    ticket_changes = ticket_changes.slice(*LBRR_REFLECTION_KEYS).sort_by { 
      |k, v| LBRR_REFLECTION_KEYS.index(k)
    }.to_h
    ticket_changes.symbolize_keys!
    ticket_changes.keys.each do |key|
      case true
      when [:deleted, :spam].include?(key)
        state = spam || deleted
        operation = state ? "decr" : "incr"
        actions.push([operation, 
                      fetch_lbrr_id(ticket_changes, :responder_id, state), 
                      fetch_lbrr_id(ticket_changes, :group_id, state)])
        break
      
      when key == :status
        status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(account)
        if lbrr_status_change?(status_ids, status, ticket_changes[:status][0])
          operation = "incr"
          state = false
        elsif lbrr_status_change?(status_ids, ticket_changes[:status][0], status)
          operation = "decr"
          state = true
        end
        if operation.present?
          actions.push([operation, 
                        fetch_lbrr_id(ticket_changes, :responder_id, state), 
                        fetch_lbrr_id(ticket_changes, :group_id, state)])
          break
        end
      
      when [:responder_id, :group_id].include?(key)
        ["decr", "incr"].each_with_index do |operation, index|
          state = index==0 ? true : false
          g_id = fetch_lbrr_id(ticket_changes, :group_id, state)
          u_id = fetch_lbrr_id(ticket_changes, :responder_id, state)
          t_group = account.groups.find_by_id(g_id)
          actions.push([operation, u_id, g_id]) if t_group.present? && 
                                                   t_group.round_robin_capping_enabled?
        end
        break
      end
    end
    actions.each do |act|
      send("#{act[0]}_agent_capping_limit", act[1], act[2])
    end
  end

  def incr_agent_capping_limit agent_id, group_id
    group = account.groups.find_by_id group_id
    if agent_id.present?
      ret = change_agents_ticket_count(group, agent_id, "incr")
      assign_agent_via_round_robin if !ret
    else
      assign_agent_via_round_robin
    end
  end

  def decr_agent_capping_limit agent_id, group_id
    group = account.groups.find_by_id group_id
    if agent_id.present?
      change_agents_ticket_count(group, agent_id, "decr")
    else
      group.lrem_from_rr_capping_queue(display_id) if group.present?
    end
  end

  def rr_allowed_on_update?
    group and (group.round_robin_enabled? and Account.current.features?(:round_robin_on_update))
  end

  def capping_ready?
    return unless capping_conditions #avoid the status query if the basic conditions are not met
    has_capping_status?
  end

  def capping_conditions
    visible? && responder_id.nil? && group_id.present?
  end

  def visible?
    !deleted? && !spam?
  end

  def has_capping_status? _status=self.status
    status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(account)
    status_ids.include?(_status)
  end

  def has_valid_status? ticket_changes
    has_capping_status?(ticket_changes.has_key?(:status) ? status_was : status)
  end

  def set_sbrr_skill_activity
    activity_type = {:type => "round_robin"}
    if self.model_changes.has_key?(:sl_skill_id)
      skill_name = Account.current.skills_from_cache.find {|skill| skill.id == self.sl_skill_id.to_i}.try(:name) if self.sl_skill_id.present?
      activity_type.merge!(:skill_name =>[nil, skill_name]) if skill_name.present?
    end
    self.activity_type = activity_type if activity_type.has_key?(:skill_name)
  end

  def set_round_robin_activity
    activity_type = self.activity_type || {:type => "round_robin"}
    activity_type.merge!(:responder_id => [nil, self.responder_id])
    self.activity_type = activity_type
  end

  def change_agents_ticket_count group, user_id, operation
    if user_id.nil? or group.nil?
      group.lrem_from_rr_capping_queue(self.display_id) if group.present? && operation=="decr"
      return
    end
    
    key = group.round_robin_capping_key
    old_score = -1

    MAX_CAPPING_RETRY.times do
      old_score = zscore_round_robin_redis(key, user_id)
      Rails.logger.debug "score for ticket #{display_id} : #{old_score}"
      next unless old_score.present?

      agent_key = group.round_robin_agent_capping_key(user_id)
      watch_round_robin_redis(agent_key)
      
      ticket_count     = agents_ticket_count(old_score)
      new_ticket_count = operation=="decr" ? ticket_count-1 : ticket_count+1

      new_score = generate_new_score(new_ticket_count)

      result = group.update_agent_capping_with_lock(user_id, new_score, operation)

      if result.is_a?(Array) && result[1].present?
        status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(account)
        db_count = group.tickets.visible.where("responder_id = ? and status in (?)", user_id, status_ids).count
        Rails.logger.debug "RR SUCCESS #{operation}ementing count for ticket : #{display_id} - 
          #{user_id}, #{group.id}, #{status_ids.inspect}, #{new_score}, #{db_count}, #{result.inspect}".squish
        if operation=="incr"
          group.lrem_from_rr_capping_queue(self.display_id)
        else
          resp = group.agents.find_by_id(user_id)
          resp.agent.assign_next_ticket(group) if resp.present?
        end
        return true
      end
      Rails.logger.debug "RR FAILED #{operation}ementing count for ticket : #{display_id} - 
        #{user_id}, #{group.id}, #{new_score}, #{result.inspect}".squish
    end
    unless old_score.present?
      Rails.logger.debug "retruning since old_score not present"
      group.lrem_from_rr_capping_queue(self.display_id) if operation=="decr"
      return true
    end
    false
  end

  def update_capping_on_create
    if group.present? && responder_id.present? && visible? && 
        group.round_robin_capping_enabled? && has_capping_status?
      change_agents_ticket_count(group, responder_id, "incr")
      self.round_robin_assignment = true
    end
  end

  private

  def fetch_lbrr_id ticket_changes, key, state=false
    ticket_changes.has_key?(key) ? ticket_changes[key][state ? 0 : 1] : 
                                   send(key.to_s)
  end

  def lbrr_status_change? status_ids, status, old_status
    status_ids.include?(status) && status_ids.exclude?(old_status)
  end

  def skip_rr_on_update?
    #Option to toggle round robin off in L2 script
    return true unless rr_allowed_on_update?
    return true if Thread.current[:skip_round_robin].present?

    #Don't trigger in case this update is a user action and it will trigger observer
    return true if user_present? && !filter_observer_events(false).blank?

    #Don't trigger during an observer save, as we call RR explicitly in the worker
    return true if Thread.current[:observer_doer_id].present?

    # Don't trigger if its already set via dispatcher
    return true if round_robin_assignment

    #Trigger RR if the update is from supervisor 
    false    
  end
  
  def round_robin_conditions(ticket_changes)
    #return if no change was made to the group
    return if !ticket_changes.has_key?(:group_id)
    #skip if agent is assigned in the transaction
    return if ticket_changes.has_key?(:responder_id) && self.responder_id.present?
    #skip if the existing agent also belongs to the new group
    return if self.responder_id.present? && 
              Account.current.agent_groups.exists?(:user_id => self.responder_id, 
                                                   :group_id => group_id)
    true
  end
  
  def update_old_group_capping
    if @model_changes.present? && @model_changes.key?(:group_id) && 
      !self.group.try(:round_robin?)
      old_group = Account.current.groups.find_by_id(@model_changes[:group_id][0])
      return unless old_group.present? && old_group.lbrr_enabled?
      if responder_id.present?
        change_agents_ticket_count(old_group, responder_id, "decr")
      else
        change_agents_ticket_count(old_group, 
          @model_changes[:responder_id][0], "decr") if @model_changes.key?(:responder_id)
        old_group.lrem_from_rr_capping_queue(display_id)
      end
    end
  end
end
