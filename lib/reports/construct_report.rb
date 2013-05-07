module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    date_condition
    merge_hash(fetch_tkts_and_data)
  end

 def merge_hash(data_hash)
  data = {}
  data_hash.each do |rec|
    responder_hash = {}
    responder = rec.send("#{@val}_id").blank? ? "Unassigned" : rec.send("#{@val}_id")
    if data.has_key?(responder)
      responder_hash = data.fetch(responder)
    end
    responder_hash.store(:tot_tkts,rec.count)
    responder_hash.store(:average_first_response_time, rec.afrt)
    responder_hash.store(:fcr, rec.fcr)
    responder_hash.store(:tkt_res_on_time, rec.otr)
    responder_hash.store(:average_response_time, rec.art)
    data.store(responder,responder_hash)
  end
  data
 end
 
 def date_condition
    " helpdesk_ticket_states.resolved_at > '#{start_date}' and helpdesk_ticket_states.resolved_at < '#{end_date}' "
   end

 def fetch_tkts_and_data 
  # Calculating Avg. 1st response time, First call resolution and On time resolution all in the same query
  tkt_scoper.find( 
     :all,
     :include => @val, 
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id", 
     :select => "#{@val}_id, 
                avg(helpdesk_ticket_states.avg_response_time) art,
                avg(TIME_TO_SEC(TIMEDIFF(helpdesk_ticket_states.first_response_time, helpdesk_tickets.created_at))) afrt, 
                sum(case when helpdesk_ticket_states.inbound_count = 1 then 1 else 0 end ) fcr, 
                sum(case when (helpdesk_tickets.due_by >= helpdesk_ticket_states.resolved_at) then 1 else 0 end) otr, 
                count(*) count", 
     :conditions => "#{date_condition}",
     :group => "#{@val}_id")
 end

 def tkt_scoper
   current_account.tickets.visible.resolved_and_closed_tickets
 end
  
end