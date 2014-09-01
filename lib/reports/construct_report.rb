module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    data = (parse_start_date == parse_end_date) ? 
                     fetch_tkts_and_data : fetch_tkts_and_data_from_redshift
    merge_hash(data)
  end

  def merge_hash(data_hash)
    data = {}
    data_hash.each do |rec|
      responder_hash = {}
      responder = rec["#{@val}_id"].blank? ? "Unassigned" : rec["#{@val}_id"].to_i
      responder_hash.store(:tot_tkts,rec['resolved_tickets'])
      responder_hash.store(:average_first_response_time, rec['avgfirstresptime'])
      responder_hash.store(:fcr, rec['fcr_tickets'])
      responder_hash.store(:tkt_res_on_time, rec['sla_tickets'])
      responder_hash.store(:average_response_time, rec['avgresponsetime']) 
      responder_hash.store(:average_resolution_time, rec['avgresolutiontime'])
      data.store(responder,responder_hash)
    end
    data
  end

  def fetch_tkts_and_data_from_redshift
    r_db = Reports::RedshiftQueries.new({:start_time => start_date, :end_time => end_date})
    options = {:select_cols => "#{r_db.summary_report_metrics}, #{@val}_id", 
      :conditions => r_db.conditions ,:group_by => "#{@val}_id"}
    r_db.execute(options)
  end


 ## Added below methods for today report where it hits our slave db.
 def tkt_scoper
   current_account.tickets.visible.resolved_and_closed_tickets
 end

 def fetch_tkts_and_data 
  # Calculating Avg. 1st response time, First call resolution and On time resolution all in the same query
  tkt_scoper.find( 
     :all,
     :include => @val, 
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id", 
     :select => "#{@val}_id, 
                avg(helpdesk_ticket_states.avg_response_time) as avgresponsetime,
                avg(TIME_TO_SEC(TIMEDIFF(helpdesk_ticket_states.first_response_time, helpdesk_tickets.created_at))) as avgfirstresptime, 
                sum(case when helpdesk_ticket_states.inbound_count = 1 then 1 else 0 end ) as fcr_tickets, 
                sum(case when (helpdesk_tickets.due_by >= helpdesk_ticket_states.resolved_at) then 1 else 0 end) as sla_tickets, 
                avg(helpdesk_ticket_states.resolution_time_by_bhrs) as avgresolutiontime,
                count(*) as resolved_tickets", 
     :conditions => "#{date_condition}",
     :group => "#{@val}_id")
 end

 def date_condition
  " helpdesk_ticket_states.resolved_at > '#{start_date_db}' and helpdesk_ticket_states.resolved_at < '#{end_date_db}' "
 end

 def start_date_db(zone = true)
    t = zone ? Time.zone : Time
    parse_start_date.nil? ? (t.now.ago 30.day).beginning_of_day.to_s(:db) : 
        t.parse(parse_start_date).beginning_of_day.to_s(:db) 
end

def end_date_db(zone = true)
  t = zone ? Time.zone : Time
  parse_end_date.nil? ? t.now.end_of_day.to_s(:db) : 
      t.parse(parse_end_date).end_of_day.to_s(:db)
end

def parse_start_date
  params[:date_range].blank? ? start_date : ( (params[:date_range].split(" - ")[0]) || params[:date_range])
end

def parse_end_date
  params[:date_range].blank? ? end_date : ((params[:date_range].split(" - ")[1]) || params[:date_range])
end
  
end