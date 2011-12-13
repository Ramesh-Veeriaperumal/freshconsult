module Reports::CompanyReport
  
  include Reports::ChartGenerator
  
  def columns
    [:status,:ticket_type,:priority]
  end
  
  def pie_chart_columns
    [:ticket_type,:priority]
  end
  
  def company_activity(params)
    columns.each do |column_name|
      tickets_count = group_tkts_by_columns(params,{:column_name => column_name })
        tickets_hash = get_tickets_hash(tickets_count,column_name)
        self.instance_variable_set("@#{column_name}_hash", tickets_hash)
    end
  end
  
  def calculate_resolved_on_time(params)
     resolved_count = count_of_resolved_on_time(params)
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets != 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     
     last_month_resolved_count = last_month_count_of_resolved_on_time(params)
     if !@last_month_tot_tickets.nil? and @last_month_tot_tickets != 0
       avg_last_month = (last_month_resolved_count.to_f/@last_month_tot_tickets.to_f) * 100
     end
   
     if !avg_last_month.nil? and !@avg_sla_current_month.nil?
       @sla_diff = @avg_sla_current_month - avg_last_month
       @sla_diff = sprintf( "%0.02f", @sla_diff)
     end
  end
  
  def count_of_tickets_last_month
   @last_month_tot_tickets = scoper(start_of_last_month(params[:date][:month].to_i).month).count 
  end
  
  def count_of_resolved_on_time(params)
    scoper(params[:date][:month].to_i).resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
  end
  
  def last_month_count_of_resolved_on_time(params)
    scoper(start_of_last_month(params[:date][:month].to_i).month).resolved_and_closed_tickets.company_tickets_resolved_on_time(params[:customer_id]).count
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
    gen_pie_chart(tickets_hash,column_name)
    tickets_hash
  end
  
   def calculate_percentage_for_columns(tickets_hash,tkts_count)
    new_val_hash = {}
    unless tickets_hash.empty?
     tickets_hash.each do |key,val_hash|
       val_per  = (val_hash.fetch(:count).to_f/tkts_count.to_f) * 100
       val_hash.store(:percentage,sprintf( "%0.02f", val_per))
       new_val_hash.store(key,val_hash)
     end
   end
   new_val_hash
  end
  
  def group_tkts_by_columns(params,vals={})
    scoper(params[:date][:month]).find( 
     :all,
     :joins => :requester,
     :select => "count(*) count, #{vals[:column_name]}",
     :conditions => { :users => {:customer_id => "#{params[:customer_id]}"}},
     :group => "#{vals[:column_name]}")
  end
  
  def scoper(month=Time.current.month)
    Account.current.tickets.created_at_inside(start_of_month(month.to_i),end_of_month(month.to_i))
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