module Reports::TimesheetReport
  
      
  def valid_month?(time)
    time.is_a?(Numeric) && (1..12).include?(time)
  end
  
  def start_of_month(month=Time.current.month)
    Time.utc(Time.now.year, month, 1) if valid_month?(month)
  end
  
  def end_of_month(month)
    start_of_month(month).end_of_month
  end
  
  def csv_hash
    {"Agent"=>:agent_name, "Hours"=> :hours, "Date" =>:start_time ,"Ticket"=>:ticket_display, "Note"=>:note  }
  end
  
  private
  def set_selected_tab
    @selected_tab = :reports
  end
  
end