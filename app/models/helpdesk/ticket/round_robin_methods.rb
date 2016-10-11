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
    ticket_changes  = merge_to_observer_changes(user_changes,self.changes) if user_changes.present?
    
    if group.round_robin_capping_enabled?
      check_capping_conditions(ticket_changes)
    elsif round_robin_conditions(ticket_changes)
      assign_agent_via_round_robin
    end
  end
  
  def assign_agent_via_round_robin
    return unless group.present?
    next_agent = if group.round_robin_capping_enabled?
      group.next_agent_with_capping(self.display_id) if capping_ready?
    elsif group.round_robin_enabled?
      group.next_available_agent
    end

    return if next_agent.nil? #There is no agent available to assign ticket.
    self.round_robin_assignment = true
    self.responder_id           = next_agent.user_id
    self.set_round_robin_activity
  end  

  def check_capping_conditions(ticket_changes)
    if ticket_changes.has_key?(:deleted) && has_valid_status?(ticket_changes)
      ticket_changes[:deleted][1] ? decr_agent_capping_limit : incr_agent_capping_limit
    elsif ticket_changes.has_key?(:spam) && has_valid_status?(ticket_changes)
      ticket_changes[:spam][1] ? decr_agent_capping_limit : incr_agent_capping_limit
    end
    if round_robin_conditions(ticket_changes)
      ticket_changes[:group_id][1].present? ? assign_agent_via_round_robin : decr_agent_capping_limit
      if ticket_changes[:group_id][0].present?
        old_group = account.groups.find_by_id(ticket_changes[:group_id][0])
        if old_group.present? && old_group.round_robin_capping_enabled?
          old_group.lrem_from_rr_capping_queue(self.display_id)
          change_agents_ticket_count(old_group, responder_id, "decr")
        end
      end
      return
    end
    return if self.round_robin_assignment
    if ticket_changes.has_key?(:responder_id) && self.group_id.present? && 
       !self.round_robin_assignment && !ticket_changes.has_key?(:round_robin_assignment)
      old_group_id = ticket_changes[:responder_id][0].present? ? self.group_id : nil
      new_group_id = ticket_changes[:responder_id][1].present? ? self.group_id : nil
      balance_agent_capping({ :group_id => [old_group_id, new_group_id], 
                              :responder_id => [ticket_changes[:responder_id][0],
                                                ticket_changes[:responder_id][1]]})
      assign_agent_via_round_robin if !ticket_changes[:responder_id][1].present?
      return
    end
    
    if ticket_changes.has_key?(:status)
      status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(account)
      if status_ids.include?(status) && !status_ids.include?(ticket_changes[:status][0])
        if responder.present?
          incr_agent_capping_limit if responder.agent.available?
        else
          assign_agent_via_round_robin
        end
      elsif !status_ids.include?(status) && status_ids.include?(ticket_changes[:status][0])
        decr_agent_capping_limit
      end
    end
  end

  def balance_agent_capping ticket_changes
    return unless has_capping_status?
    ["decr", "incr"].each_with_index do |operation, index|
      g_id = ticket_changes[:group_id][index]
      u_id = ticket_changes[:responder_id][index]
      t_group = account.groups.find_by_id(g_id)
      change_agents_ticket_count(t_group, u_id, operation) if t_group.present? && 
                                                              t_group.round_robin_capping_enabled?
    end
  end

  def incr_agent_capping_limit
    if self.group.present?
      if self.responder_id.present?
        ret = change_agents_ticket_count(self.group, responder_id, "incr") if responder_id.present?
        assign_agent_via_round_robin if !ret
      else
        assign_agent_via_round_robin
      end
    end
  end

  def decr_agent_capping_limit
    if self.group.present?
      if responder_id.present?
        change_agents_ticket_count(self.group, responder_id, "decr")
      else
        group.lrem_from_rr_capping_queue(self.display_id)
      end
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
  
  def set_round_robin_activity
    self.activity_type = {:type => "round_robin", :responder_id => [nil, self.responder_id]}
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
        Rails.logger.debug "RR SUCCESS #{operation}ementing count for ticket : #{display_id} - 
          #{user_id}, #{group.id}, #{new_score}, #{result.inspect}".squish
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
    end
  end

  private

  def skip_rr_on_update?
    #Option to toggle round robin off in L2 script
    return true unless rr_allowed_on_update?
    return true if Thread.current[:skip_round_robin].present?

    #Don't trigger in case this update is a user action and it will trigger observer
    return true if user_present? && !filter_observer_events(false).blank?

    #Don't trigger during an observer save, as we call RR explicitly in the worker
    return true if Thread.current[:observer_doer_id].present?

    #Trigger RR if the update is from supervisor 
    false    
  end
  
  def round_robin_conditions(ticket_changes)
    #return if no change was made to the group
    return if !ticket_changes.has_key?(:group_id)
    return true if self.responder_id.nil?
    #skip if agent is assigned in the transaction
    if ticket_changes.has_key?(:responder_id)
      balance_agent_capping(ticket_changes)
      self.round_robin_assignment = true
      return
    end
    #skip if the existing agent also belongs to the new group
    if agent_in_new_group?
      balance_agent_capping(ticket_changes.merge(:responder_id => [responder_id, responder_id]))
      self.round_robin_assignment = true
      return
    end
    true
  end
  
  def agent_in_new_group?
    group_id.present? and Account.current.agent_groups.exists?(:user_id => self.responder_id, :group_id => group_id)
  end

  def update_old_group_capping
    if @model_changes.present? && @model_changes.key?(:group_id) && 
                                  @model_changes[:group_id][1].nil?
      old_group = Account.current.groups.find_by_id(@model_changes[:group_id][0])
      return unless old_group.present? && old_group.round_robin_capping_enabled?
      if responder_id.present?
        change_agents_ticket_count(old_group, responder_id, "decr")
      else
        old_group.lrem_from_rr_capping_queue(display_id)
      end
    end
  end
end
