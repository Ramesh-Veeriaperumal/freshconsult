class ReportsController < Admin::AdminController
  
  include Reports::ConstructReport
  
  def index
   rep_tkts = fetch_tkts_by_status
   @tkts_by_status = tkts_by_status(rep_tkts)
   
   @tkts_res_by_time = fetch_tkt_res_on_time
   @tkts_over_due = fetch_overdue_tkts
   
  end
 
 protected
 
 def fetch_tkts_by_status
   scoper.tickets.find( :all,
     :include => :responder, 
     :select => 'count(*) count, responder_id,status', 
     :group => 'responder_id,status')
 end
 
 def fetch_tkt_res_on_time
   scoper.tickets.find(
     :all, 
     :select => 'count(*) count, responder_id', 
     :include => :responder,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => ['helpdesk_tickets.status IN (?,?) and helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at',TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]],
     :group => 'responder_id')
 end
 
  
 def fetch_overdue_tkts
   scoper.tickets.find(
     :all, 
     :select => 'count(*) count, responder_id', 
     :include => :responder,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at  || (helpdesk_ticket_states.resolved_at is null and   helpdesk_tickets.due_by < now() )) ",
     :group => 'responder_id')
 end
 
 def scoper
   current_account
 end
  
end