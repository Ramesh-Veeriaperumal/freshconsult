module Reports::ActivityReport
  
  def fetch_activity(params)
    unless params[:reports].nil?
      columns_to_use = params[:reports]
      pie_chart_columns.push params[:reports].each
    else
      columns_to_use = columns
    end
    
    # Including Status hash by default
    columns_to_use.push :status unless columns_to_use.include?(:status)
    
    columns_to_use.each do |column_name|
      tickets_count = group_tkts_by_columns(params,{:column_name => column_name })
      
      tickets_hash = get_tickets_hash(tickets_count,column_name)
      self.instance_variable_set("@#{column_name.to_s.gsub('.', '_')}_hash", tickets_hash)
    end

    # Forcing generation of Status chart
    source_chart(params)
  end

  def source_chart(params)
    tickets_count = group_tkts_by_columns(params,{:column_name => "source" })
    tickets_hash = get_tickets_hash(tickets_count,"source", :stacked_bar_single)
    self.instance_variable_set("@source_hash", tickets_hash)
  end
  
  def add_resolved_and_closed_tickets(hash)
    hash.fetch(TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],{}).fetch(:count,0).to_i + hash.fetch(TicketConstants::STATUS_KEYS_BY_TOKEN[:closed],{}).fetch(:count,0).to_i
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
 
  #Need to think ?
  def scoper(starting_time = nil, ending_time = nil)
    ending_time ||= @ending_date
    starting_time ||= @starting_date
    Account.current.tickets.created_at_inside(starting_time.to_time.to_s(:db),ending_time.to_time.to_s(:db))
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

  def starting_time
    params[:date_range] ||= 30.days.ago(:db)
  end
  
  
  def calc_times(params) 
    dates = time_range = params["dateRange"].split(" - ")
    @starting_date = dates[0].to_time
    @ending_date = dates[1].to_time
    
    distance_between_dates = @ending_date - @starting_date
    @prev_ending = @starting_date - 1.day
    @prev_starting = @prev_ending - distance_between_dates
  end
  
  
end