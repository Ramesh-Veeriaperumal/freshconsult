module Reports::TimesheetReport
  
  include Reports::ActivityReport
      
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
    {"Agent"=>:agent_name, "Hours"=> :hours, "Date" =>:executed_at ,"Ticket"=>:ticket_display, 
                                 "Product"=>:product_name , "Group"=>:group_name , "Note"=>:note,
                                 "Customer" => :customer_name ,"Billable/Non-Billable" => :billable_type}
  end
  
  def list_view_items
   [:workable , :customer_name , :note , :group_by_day_criteria , :agent_name, :product_name ,
                                                                             :group_name , :hours]
  end
  
  private
  def set_selected_tab
    @selected_tab = :reports
  end
  
  def build_item
    @start_date = start_date
    @end_date = end_date
    @customer_id = params[:customer_id] || []
    @user_id = params[:user_id] || []
    @headers = list_view_items.delete_if{|item| item == group_by_caluse }
    @billable = billable_and_non? ? [true, false] : [params[:billable].to_s.to_bool]
    @group_id = params[:group_id] || []

end

  def billable_and_non?
    params[:billable].blank? or (params[:billable].include?("true") and params[:billable].include?("false"))
  end

  def group_by_caluse
    group_by_caluse = params[:group_by] || :customer_name
    group_by_caluse = group_by_caluse.to_sym()  
  end


  
end