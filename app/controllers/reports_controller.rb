class ReportsController < Admin::AdminController
  
  include Reports::ConstructReport
  
  def index
    
   val = "responder"
   
   rep_tkts_by_agts = fetch_tkts_by_status(val)
   @agts_tkts_by_status = tkts_by_status(rep_tkts_by_agts,val)
   @agts_tkts_res_by_time = fetch_tkt_res_on_time(val)
   @agts_tkts_over_due = fetch_overdue_tkts(val)
   
   val = "group"
   
   rep_tkts_by_grps = fetch_tkts_by_status(val)
   @grps_tkts_by_status = tkts_by_status(rep_tkts_by_grps,val)
   @grps_tkts_res_by_time = fetch_tkt_res_on_time(val)
   @grps_tkts_over_due = fetch_overdue_tkts(val)
   
  end
 
 protected
 
 def fetch_tkts_by_status(val)
   scoper.tickets.find( :all,
     :include => val, 
     :select => "count(*) count, #{val}_id,status", 
     :group => "#{val}_id,status")
 end
 
 def fetch_tkt_res_on_time(val)
   scoper.tickets.find(
     :all, 
     :select => "count(*) count, #{val}_id", 
     :include => val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => ['helpdesk_tickets.status IN (?,?) and helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at',TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]],
     :group => "#{val}_id")
 end
 
  
 def fetch_overdue_tkts(val)
   scoper.tickets.find(
     :all, 
     :select => "count(*) count, #{val}_id", 
     :include => val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at  || (helpdesk_ticket_states.resolved_at is null and   helpdesk_tickets.due_by < now() )) ",
     :group => "#{val}_id")
 end
 
 def scoper
   current_account
 end
  
end