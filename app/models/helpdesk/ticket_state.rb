class Helpdesk::TicketState <  ActiveRecord::Base
  belongs_to_account
  set_table_name "helpdesk_ticket_states"
  belongs_to :tickets , :class_name =>'Helpdesk::Ticket',:foreign_key =>'ticket_id'
  
  attr_protected :ticket_id
  
  def reset_tkt_states
    self.resolved_at = nil
    self.closed_at = nil
  end
  
  def set_resolved_at_state
    self.resolved_at=Time.zone.now
  end
  
  def set_closed_at_state
    set_resolved_at_state if resolved_at.nil?
    self.closed_at=Time.zone.now
  end
  
  def need_attention
    first_response_time.blank? or (requester_responded_at && agent_responded_at && requester_responded_at > agent_responded_at)
  end
  
  def is_new?
    first_response_time.blank?
  end

  def customer_responded?
    (requester_responded_at && agent_responded_at && requester_responded_at > agent_responded_at)
  end

  def current_state

    if (closed_at && status_updated_at && status_updated_at > closed_at) #inapportune case
        return TICKET_LIST_VIEW_STATES[:resolved_at] if(resolved_at && resolved_at > closed_at )
        return TICKET_LIST_VIEW_STATES[:created_at] if(agent_responded_at.nil?)
        return TICKET_LIST_VIEW_STATES[:agent_responded_at] 
    end

    return TICKET_LIST_VIEW_STATES[:closed_at] if closed_at
    
    if (resolved_at && status_updated_at && status_updated_at > resolved_at) #inapportune case
      return TICKET_LIST_VIEW_STATES[:created_at] if(agent_responded_at.nil?)
      return TICKET_LIST_VIEW_STATES[:agent_responded_at] 
    end
    
    return TICKET_LIST_VIEW_STATES[:resolved_at] if resolved_at
    
    return TICKET_LIST_VIEW_STATES[:requester_responded_at] if customer_responded?
    return TICKET_LIST_VIEW_STATES[:agent_responded_at] if agent_responded_at
    return TICKET_LIST_VIEW_STATES[:created_at]
  end


private
  TICKET_LIST_VIEW_STATES = { :created_at => "created_at", :closed_at => "closed_at", 
    :resolved_at => "resolved_at", :agent_responded_at => "agent_responded_at", 
    :requester_responded_at => "requester_responded_at" }

end
