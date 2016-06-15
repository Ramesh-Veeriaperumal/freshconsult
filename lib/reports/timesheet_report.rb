module Reports::TimesheetReport
  
  include Reports::ActivityReport
  include HelpdeskReports::Helper::ControllerMethods
      
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
         :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]]) # need to ensure - Hari

  end

  def time_sheet_list
    @report_date = params[:date_range]
    current_range_time_sheet
    previous_range_time_sheet #Fetching the previous time range data.
    if Account.current.features?(:archive_tickets)
      archive_current_range_time_sheet
      archive_previous_range_time_sheet
      sum_new_and_archived
      sum_data
    end
    stacked_chart_data
  end

  def previous_range_time_sheet
    #set the time (start/end) to previous range for comparison summary.
    set_time_range(true)
    old_time_sheets = filter_with_groupby(@start_time,@end_time)
    @old_time_sheet_data = billable_vs_non_billable(old_time_sheets)
  end

  def time_sheet_for_export
    @time_sheets = filter(@start_date,@end_date)
    if Account.current.features?(:archive_tickets)
      @archive_time_sheets = archive_filter(@start_date,@end_date)
      @time_sheets = shift_merge_sorted_arrays(@time_sheets,@archive_time_sheets)
    end
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
         :include => [:user, :workable => [:product, :group, :ticket_status, :requester, :company]]) # need to ensure - Hari
  end

  def archive_select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:archive_tickets => conditions} unless conditions.blank?
  end

  #************************** Archive methods stop here *****************************#

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:helpdesk_tickets => conditions} unless conditions.blank?
  end

  def set_selected_tab
    @selected_tab = :reports
  end

  def set_report_type
    @report_type         = :timesheet_reports
    @user_time_zone_abbr = Time.zone.now.zone
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

def set_time_range(prev_time = false)
    @start_time = prev_time ? previous_start : start_date
    @end_time = prev_time ? previous_end : end_date  
  end
  
  
  def current_range_time_sheet
    @time_sheets = filter_with_groupby(@start_date,@end_date)    
    @time_sheet_data = billable_vs_non_billable(@time_sheets)
  end

  def check_permission
    access_denied unless privilege?(:view_time_entries)
  end

  def stacked_chart_data
    barchart_data = [{:name=>"non_billable",:data=>[@time_sheet_data[:non_billable]],:color=>'#bbbbbb'},{:name=>"billable",:data=>[@time_sheet_data[:billable]],:color=>'#679d46'}]
    @activity_data_hash={'barchart_data'=>barchart_data}
  end

  def parse_date(date_time)
    date_time.strftime("%Y-%m-%d %H:%M:%S")
  end

  #******** Archive method starts here ********#
  
  def archive_previous_range_time_sheet
    #set the time (start/end) to previous range for comparison summary.
    set_time_range(true)
    old_time_sheets = archive_filter_with_groupby(@start_time,@end_time)
    @archive_old_time_sheet_data= billable_vs_non_billable(old_time_sheets)
  end

  def archive_current_range_time_sheet
    @archive_time_sheets = archive_filter_with_groupby(@start_date,@end_date)    
    @archive_time_sheet_data = billable_vs_non_billable(@archive_time_sheets)
  end

  def sum_new_and_archived
    @time_sheet_data.each do |key,value|
      @time_sheet_data[key] = value + @archive_time_sheet_data[key]
    end
    @old_time_sheet_data.each do |key,value|
      @old_time_sheet_data[key] = value + @archive_old_time_sheet_data[key]
    end
  end

  def sum_data
    @archive_time_sheets.each do |key,value|
      if @time_sheets[key]
        @time_sheets[key] = shift_merge_sorted_arrays(@time_sheets[key],value)
      else
        @time_sheets[key] = value
      end
    end
  end

  def shift_merge_sorted_arrays(array1,array2)
    output = []
    loop do
      break if array1.empty? || array2.empty?
      output << (array1.first.executed_at > array2.first.executed_at ? array1.shift : array2.shift)
    end
    return output + array1 + array2
  end

  #******** Archive method ends here ********#



  
end