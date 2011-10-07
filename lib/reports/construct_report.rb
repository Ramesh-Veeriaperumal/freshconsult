module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    date_condition(params)
    @global_hash = tkts_by_status(fetch_tkts_by_status)
    merge_hash(:tkt_res_on_time,fetch_tkt_res_on_time)
    merge_hash(:over_due_tkts,fetch_overdue_tkts)
    merge_for_fcr(:fcr,fetch_fcr)
    @global_hash
  end
  
  def merge_for_fcr(key,res_hash)
   res_hash.each do |tkt|
     responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
     status_hash = @global_hash.fetch(responder)
     status_hash.store(key,tkt.count)
     tot_tkts = status_hash.fetch(:tot_tkts)
     fcr_per = (tkt.count.to_f/tot_tkts.to_f) * 100
     status_hash.store(key,tkt.count)
     status_hash.store(:fcr_per,sprintf( "%0.02f", fcr_per))
     @global_hash.store(responder,status_hash)
  end
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
 
 def date_condition(params)
   @date_condition ||= begin 
    date_con = " helpdesk_tickets.created_at between '#{1.month.ago.to_s(:db)}' and now() "
    unless params[:start_date].blank? and params[:end_date].blank?
      date_con = " helpdesk_tickets.created_at > '#{DateTime.parse(params[:start_date])}' and helpdesk_tickets.created_at < '#{DateTime.parse(params[:end_date])}' "
    end
    date_con
   end
 end
 
 def fetch_tkts_by_type
   tkt_scoper.find( 
     :all,
     :include => @val, 
     :select => "count(*) count, ticket_type", 
     :conditions => @date_condition,
     :group => "ticket_type")
 end
 
 def fetch_tkts_by_status
   tkt_scoper.find( 
     :all,
     :include => @val, 
     :select => "count(*) count, #{@val}_id,status", 
     :conditions => @date_condition,
     :group => "#{@val}_id,status")
 end
 
 def fetch_tkt_res_on_time
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => ["helpdesk_tickets.status IN (?,?) and helpdesk_tickets.due_by >  helpdesk_ticket_states.resolved_at and (#{@date_condition})",TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]],
     :group => "#{@val}_id")
 end
 
  
 def fetch_overdue_tkts
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at  || (helpdesk_ticket_states.resolved_at is null and   helpdesk_tickets.due_by < now() )) and (#{@date_condition}) ",
     :group => "#{@val}_id")
 end
 
 def fetch_fcr
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1 and (#{@date_condition}) ",
     :group => "#{@val}_id")
 end
 
 def tkt_scoper
   scoper.tickets
 end
 
 def scoper
   Account.current
 end
 
end