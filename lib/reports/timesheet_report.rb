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
                                 "Customer" => :customer_name ,"Billable/Non-Billable" => :billable_type,
                                 "Priority"=>:priority_name, "Status"=>:status_name,
                                  "Created at" => :created_at}
  end
  
  def list_view_items
   [:workable , :customer_name , :priority_name, :status_name, :note , :group_by_day_criteria , :agent_name, :product_name ,
                                                                             :group_name , :hours]
  end

  def billable_vs_non_billable(time_sheets)
    total_time = 0.0
    billable_data = 0.0
    time_sheets.each do |group,time_entries|
      time_entries.each do |time_entry|
        total_time+=time_entry.running_time
        billable_data += time_entry.running_time if time_entry.billable
      end
    end
    { :total_time => total_time, :billable => billable_data, :non_billable => (total_time - billable_data) }
  end
  
  def scoper(start_date,end_date)
    Account.current.time_sheets.for_companies(@customer_id).by_agent(@user_id).by_group(@group_id).created_at_inside(start_date,end_date).hour_billable(@billable).for_products(@products_id)
  end

  def filter_with_groupby(start_date,end_date)
    filter(start_date,end_date).group_by(&group_by_caluse)
  end 

  def filter(start_date,end_date)
       scoper(start_date,end_date).find(:all,:conditions => (select_conditions || {}), 
         :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester => [:company]]]) # need to ensure - Hari

  end

  #************************** Archive methods start here *****************************#

  def archive_scoper(start_date,end_date)
    Account.current.archive_time_sheets.archive_for_companies(@customer_id).by_agent(@user_id).archive_by_group(@group_id).created_at_inside(start_date,end_date).hour_billable(@billable).archive_for_products(@products_id)
  end

  def archive_filter_with_groupby(start_date,end_date)
    archive_filter(start_date,end_date).group_by(&group_by_caluse)
  end 

  def archive_filter(start_date,end_date)
       archive_scoper(start_date,end_date).find(:all,:conditions => (archive_select_conditions || {}), 
         :include => [:user, :workable => [:product, :group, :ticket_status, :requester => [:company]]]) # need to ensure - Hari
  end

  def archive_select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:archive_tickets => conditions} unless conditions.blank?
  end

  #************************** Archive methods stop here *****************************#

  private

  def select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:helpdesk_tickets => conditions} unless conditions.blank?
  end

  def set_selected_tab
    @selected_tab = :reports
  end
  
  def build_item
    @start_date = start_date
    @end_date = end_date
    @customer_id = params[:customers] ? params[:customers].split(',') : []
    @user_id = params[:user_id] || []
    @headers = list_view_items.delete_if{|item| item == group_by_caluse }
    @billable = billable_and_non? ? [true, false] : [params[:billable].to_s.to_bool]
    @group_id = params[:group_id] || []
    @ticket_type = params[:ticket_type] || []
    @products_id = params[:products_id] || []
    @priority = params[:priority] || []

end

  def billable_and_non?
    params[:billable].blank? or (params[:billable].include?("true") and params[:billable].include?("false"))
  end

  def group_by_caluse
    group_by_caluse = params[:group_by] || :customer_name
    group_by_caluse = group_by_caluse.to_sym()  
  end


  
end