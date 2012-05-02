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
  
end
