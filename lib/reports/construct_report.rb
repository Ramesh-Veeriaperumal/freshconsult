module Reports::ConstructReport
  
  def build_tkts_hash(val)
    @val = val
    @global_hash = tkts_by_status(fetch_tkts_by_status)
    merge_hash(:tkt_res_on_time,fetch_tkt_res_on_time)
    merge_hash(:over_due_tkts,fetch_overdue_tkts)
    @global_hash
  end
  
  def tkts_by_status(tkts)
   data = {}
   tkts.each do |tkt|
    status_hash = {}
    #info_val = info.eql?("responder") ? "email" : "name"
    responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
    if data.has_key?(responder)
      status_hash = data.fetch(responder)
    end
    status_hash.store(TicketConstants::STATUS_NAMES_BY_KEY[tkt.status],tkt.count)
    tot_count = status_hash.fetch(:tot_tkts,0) + tkt.count.to_i
    status_hash.store(:tot_tkts,tot_count)
    data.store(responder,status_hash)
   end
     data
 end
 
 def merge_hash(key,res_hash)
   res_hash.each do |tkt|
     responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
     status_hash = @global_hash.fetch(responder)
     status_hash.store(key,tkt.count)
     @global_hash.store(responder,status_hash)
  end
 end
 
 def date_condition
   " helpdesk_tickets.created_at between '#{30.days.ago}' and now() "
 end
 
 def fetch_tkts_by_status
   scoper.tickets.find( :all,
     :include => @val, 
     :select => "count(*) count, #{@val}_id,status", 
     :conditions => "#{date_condition}",
     :group => "#{@val}_id,status")
 end
 
 def fetch_tkt_res_on_time
   scoper.tickets.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => ["helpdesk_tickets.status IN (?,?) and helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at and #{date_condition}",TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]],
     :group => "#{@val}_id")
 end
 
  
 def fetch_overdue_tkts
   scoper.tickets.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at  || (helpdesk_ticket_states.resolved_at is null and   helpdesk_tickets.due_by < now() ))  and #{date_condition} ",
     :group => "#{@val}_id")
 end
 
 def scoper
   Account.current
 end
 
end