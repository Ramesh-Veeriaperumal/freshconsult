module Reports::HelpdeskReport
  
  include Reports::ChartGenerator
  
  def columns
   [:status,:ticket_type,:priority,:source] 
 end
 
 def timeline_columns
   [:all,:resolved] 
 end
 
  def helpdesk_activity(params)
    columns.each do |column_name|
      tickets_count = group_tkts_by_columns(params,{:column_name => column_name })
      tickets_hash = get_tickets_hash(tickets_count,column_name,params)
      self.instance_variable_set("@#{column_name}_hash", tickets_hash)
    end
  end
  
  def calculate_resolved_on_time(params)
     resolved_count = count_of_resolved_on_time(params)
     if !@current_month_tot_tickets.nil? and !@current_month_tot_tickets != 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_resolved_count = last_month_count_of_resolved_on_time(params)
     if !@last_month_tot_tickets.nil? and @last_month_tot_tickets != 0
       avg_sla_last_month = (last_month_resolved_count.to_f/@last_month_tot_tickets.to_f) * 100
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
     if !@last_month_tot_tickets.nil? and @last_month_tot_tickets != 0
       avg_last_month = (last_month_fcr_count.to_f/@last_month_tot_tickets.to_f) * 100
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
  end
  
  def count_of_tickets_last_month
   scoper(start_of_last_month(params[:date][:month].to_i).month).count 
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
  
  def get_tickets_hash(tickets_count,column_name,params)
    tickets_hash = {}
    tickets_count.each do |ticket|
      tickets_hash.store(ticket.month,tickets_hash.fetch(ticket.month,[]).push(:value => ticket.send(column_name),:count => ticket.count))
    end
    processed_hash = {}
    processed_hash[:current_month] = tickets_hash.fetch(params[:date][:month],{})
    processed_hash[:last_month] = tickets_hash.fetch(start_of_last_month(params[:date][:month].to_i).month.to_s,{})
    post_processing(processed_hash,column_name)
  end
  
  def get_tickets_hash(tickets_count,column_name)
    tot_count = 0
    tickets_hash = {}
    tickets_count.each do |ticket|
      tot_count += ticket.count.to_i
      tickets_hash.store(ticket.send(column_name),{:count => ticket.count})
    end
    @current_month_tot_tickets = tot_count
    tickets_hash
  end
  
  def post_processing(processed_hash,column_name)
     @last_month_tot_tickets = calculate_tickets_count(processed_hash.fetch(:last_month)) 
     @current_month_tot_tickets = calculate_tickets_count(processed_hash.fetch(:current_month))
     processed_hash.store(:last_month,calculate_percentage_for_columns(processed_hash.fetch(:last_month),@last_month_tot_tickets))
     current_month_value_arr = calculate_percentage_for_columns(processed_hash.fetch(:current_month),@current_month_tot_tickets)
     gen_pie_chart(current_month_value_arr,column_name) unless current_month_value_arr.blank?
     processed_hash.store(:current_month,current_month_value_arr)
     processed_hash
  end
  
  def calculate_percentage_for_columns(val_arr,tkts_count)
    new_val_arr = []
    unless val_arr.empty?
     val_arr.each do |val_hash|
       val_per  = (val_hash.fetch(:count).to_f/tkts_count.to_f) * 100
       val_hash.store(:percentage,sprintf( "%0.02f", val_per))
       new_val_arr.push(val_hash)
     end
   end
   new_val_arr
  end
  
  def calculate_tickets_count(val_arr)
    tot_count = 0
    unless val_arr.empty?
     val_arr.each do |val_hash|
       tot_count += val_hash.fetch(:count).to_i
     end
    end
    tot_count
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
     :select => "count(*) count,DATE(created_at) date",
     :conditions => fetch_condition(type),
     :group => "DATE(created_at)")
  end
  
  def fetch_condition(type)
    return "status IN (#{TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]})" if type.to_s.eql?("resolved")
  end
  
  
  
  def scoper(month=Time.current.month)
    Account.current.tickets.created_at_inside(start_of_last_month(month.to_i),end_of_month(month.to_i))
  end
  
  def valid_month?(time)
    time.is_a?(Numeric) && (1..12).include?(time)
  end
  
  def start_of_month(month=Time.current.month)
    Time.utc(Time.now.year, month, 1) if valid_month?(month)
  end
  
  def end_of_month(month)
    start_of_month(month).end_of_month
  end
  
  def start_of_last_month(month)
    start_of_month(month).last_month
  end
  
  def end_of_last_month(month)
    start_of_last_month(month).end_of_month
  end
  
  
end