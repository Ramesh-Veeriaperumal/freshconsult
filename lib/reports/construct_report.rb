module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    date_condition
    merge_hash(fetch_tkts_and_data_from_redshift)
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

 def tkt_scoper
   current_account.tickets.visible.resolved_and_closed_tickets
 end
  
end