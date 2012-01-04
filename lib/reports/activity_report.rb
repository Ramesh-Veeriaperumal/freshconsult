module Reports::ActivityReport
  
  def fetch_activity(params)
    columns.each do |column_name|
      tickets_count = group_tkts_by_columns(params,{:column_name => column_name })
      tickets_hash = get_tickets_hash(tickets_count,column_name)
      self.instance_variable_set("@#{column_name}_hash", tickets_hash)
    end
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