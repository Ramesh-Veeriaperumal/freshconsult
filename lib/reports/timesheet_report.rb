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
    {"Agent"=>:agent_name, "Hours"=> :hours, "Date" =>:executed_at ,"Ticket"=>:ticket_display, "Note"=>:note  }
  end
  
  def list_view_items
   [:ticket , :customer_name , :note , :group_by_day_criteria ,:agent_name, :hours]
  end
  
  private
  def set_selected_tab
    @selected_tab = :reports
  end
  
  def build_item
    @start_date = params[:start_date] ?  Date.parse(params[:start_date]).beginning_of_day : start_of_month(Time.zone.now.month.to_i)
    @end_date = params[:end_date] ? Date.parse(params[:end_date]).end_of_day : Time.zone.now.end_of_day
    @customer_id = params[:customer_id] || []
    @user_id = params[:user_id] || []
    @headers = list_view_items.delete_if{|item| item == group_by_caluse }
    @billable = (!params[:billable].blank? && !params[:billable].to_s.eql?("falsetrue")) ? [params[:billable].to_s.to_bool] : [true,false]

end

  def group_by_caluse
    group_by_caluse = params[:group_by] || :customer_name
    group_by_caluse = group_by_caluse.to_sym()  
  end


  
end