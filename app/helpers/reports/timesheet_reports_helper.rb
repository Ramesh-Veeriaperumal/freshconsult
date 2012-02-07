module Reports::TimesheetReportsHelper

  def get_total_time time_sheets
      return time_sheets.collect{|t| t.hours.to_f}.sum
  end
  
end
