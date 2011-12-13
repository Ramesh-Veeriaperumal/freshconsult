module Helpdesk::TimeSheetsHelper
  
  
  def get_time_in_hours time_in_second
    hours = time_in_second.div(60*60)
    minutes_as_percent = (time_in_second.div(60) % 60)*(1.667).round
    total_time = hours.to_s()+"."+ minutes_as_percent.to_s()
    total_time
  end
  
  def get_total_time time_sheets
    total_time_in_sec = time_sheets.collect{|t| t.time_spent}.sum
    return get_time_in_hours(total_time_in_sec)
  end
  
  
end
