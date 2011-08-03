class Helpdesk::TicketState < ActiveRecord::Base
  set_table_name "helpdesk_ticket_states"
  belongs_to :tickets , :class_name =>'Helpdesk::Ticket',:foreign_key =>'ticket_id'
  
  def reset_tkt_states
    self.resolved_at = nil
    self.closed_at = nil
  end
  
  def set_resolved_at_state
    self.resolved_at=Time.zone.now
  end
  
  def set_closed_at_state
    self.closed_at=Time.zone.now
  end
end
