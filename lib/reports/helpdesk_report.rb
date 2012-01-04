module Reports::HelpdeskReport
   
  include Reports::ChartGenerator
  include Reports::ActivityReport
   
  def columns
   [:status,:ticket_type,:priority,:source] 
 end
   
  def pie_chart_columns
    [:ticket_type,:priority]
  end
  
 def timeline_columns
   [:all,:resolved] 
 end
 
  def calculate_resolved_on_time(params)
     resolved_count = count_of_resolved_on_time(params)
     if !@current_month_tot_tickets.nil? and !@current_month_tot_tickets != 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_resolved_count = last_month_count_of_resolved_on_time(params)
     last_month_tot_tickets = count_of_tickets_last_month(params)
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_sla_last_month = (last_month_resolved_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_sla_last_month.nil? and !@avg_sla_current_month.nil?
       @sla_diff = @avg_sla_current_month - avg_sla_last_month
     end
  end
  
  def calculate_fcr(params)
     fcr_count = count_of_fcr(params)
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
       @avg_fcr_month = (fcr_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_fcr_count = last_month_count_of_fcr(params)
     last_month_tot_tickets = count_of_tickets_last_month(params)
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_last_month = (last_month_fcr_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_last_month.nil? and !@avg_fcr_month.nil?
       @fcr_diff = @avg_fcr_month - avg_last_month
     end
  end
   
  def get_tickets_time_line(params)
    timeline_columns.each do |column|
      ticket_timeline = group_tkts_by_timeline(params,column)
      self.instance_variable_set("@#{column}_hash", ticket_timeline)
    end
    gen_line_chart(@all_hash,@resolved_hash)
  end
   
    
  def get_tickets_hash(tickets_count,column_name)
    tot_count = 0
    tickets_hash = {}
    tickets_count.each do |ticket|
      tot_count += ticket.count.to_i
      tickets_hash.store(ticket.send(column_name),{:count => ticket.count})
    end
    @current_month_tot_tickets = tot_count
    tickets_hash = calculate_percentage_for_columns(tickets_hash,@current_month_tot_tickets)
    gen_pie_chart(tickets_hash,column_name) if pie_chart_columns.include?(column_name)
    tickets_hash
  end
   
  def post_processing(processed_hash,column_name)
     
  end
   
  def group_tkts_by_columns(params,vals={})
    scoper(params[:date][:month]).find( 
     :all,
     :select => "count(*) count, #{vals[:column_name]}",
     :group => "#{vals[:column_name]}")
  end
   
  def group_tkts_by_timeline(params,type)
    scoper(params[:date][:month].to_i).find( 
     :all,
     :select => "count(*) count,created_at date",
     :conditions => fetch_condition(type),
     :group => "DATE(created_at)")
  end
   
  def fetch_condition(type)
    return "status IN (#{TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]})" if type.to_s.eql?("resolved")
  end
  
  def count_of_tickets_last_month(params)
    @last_month_tot_tickets ||= scoper(start_of_last_month(params[:date][:month].to_i).month).count 
  end
  
  def count_of_fcr(params)
    scoper(params[:date][:month].to_i).first_call_resolution.count
  end
   
  def last_month_count_of_fcr(params)
    scoper(start_of_last_month(params[:date][:month].to_i).month).first_call_resolution.count
  end
  
   
  def count_of_resolved_on_time(params)
    scoper(params[:date][:month].to_i).resolved_and_closed_tickets.resolved_on_time.count
  end
   
  def last_month_count_of_resolved_on_time(params)
    scoper(start_of_last_month(params[:date][:month].to_i).month).resolved_and_closed_tickets.resolved_on_time.count
  end
    
end