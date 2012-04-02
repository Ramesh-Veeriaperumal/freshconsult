module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    date_condition
    @global_hash = tkts_by_status(fetch_tkts_by_status)
    merge_hash(:tkt_res_on_time,fetch_tkt_res_on_time)
    merge_hash(:over_due_tkts,fetch_overdue_tkts)
    merge_hash(:average_first_response_time,fetch_afrt)
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
    status_hash.store(tkt.status,tkt.count)
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
   @date_condition ||= begin 
    " helpdesk_ticket_states.resolved_at > '#{start_date}' and helpdesk_ticket_states.resolved_at < '#{end_date}' "
   end
 end

 def resolved_condition
  "helpdesk_tickets.status IN (#{TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]}) and (helpdesk_ticket_states.resolved_at is not null) and (#{@date_condition})"
 end

 def fetch_tkts_by_status
   tkt_scoper.find( 
     :all,
     :include => @val, 
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :select => "count(*) count, #{@val}_id,status", 
     :conditions => resolved_condition,
     :group => "#{@val}_id,status")
 end
 
 def fetch_tkt_res_on_time
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => "#{resolved_condition} and helpdesk_tickets.due_by >=  helpdesk_ticket_states.resolved_at",
     :group => "#{@val}_id")
 end
 
  
 def fetch_overdue_tkts
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => "#{resolved_condition} and (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at )",
     :group => "#{@val}_id")
 end
 
 def fetch_fcr
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => "#{resolved_condition} and  helpdesk_ticket_states.inbound_count = 1",
     :group => "#{@val}_id")
 end
 
 # Average First Response Time
 # (Time between Ticket Creation and the First Reponse)
 def fetch_afrt
   tkt_scoper.find(
     :all, 
     :select => "avg(TIME_TO_SEC(TIMEDIFF(helpdesk_ticket_states.first_response_time, helpdesk_tickets.created_at))) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => resolved_condition,
     :group => "#{@val}_id")
 end
 
 def tkt_scoper
   scoper.tickets.visible
 end
 
 def scoper
   Account.current
 end


  def start_date
    parse_from_date.nil? ? (Time.zone.now.ago 30.day).beginning_of_day.to_s(:db) : 
        Time.zone.parse(parse_from_date).beginning_of_day.to_s(:db) 
  end
  
  def end_date
    parse_to_date.nil? ? Time.zone.now.end_of_day.to_s(:db) : 
        Time.zone.parse(parse_to_date).end_of_day.to_s(:db)
  end
  
  def parse_from_date
    params[:date_range].nil? ? nil : (params[:date_range].split(" - ")[0]) || params[:date_range]
  end
  
  def parse_to_date
    params[:date_range].nil? ? nil : (params[:date_range].split(" - ")[1]) || params[:date_range]
  end
  
end