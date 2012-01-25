class Reports::TimesheetReportsController < ApplicationController
  
  include Reports::TimesheetReport
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_selected_tab
  before_filter :build_time_sheet, :only => [:index, :export_csv ,:report_filter]

  
  def report_filter
    render :partial => "time_sheet_list"
  end
  
  def export_csv
    csv_string = FasterCSV.generate do |csv|
      headers = csv_hash.keys.sort
      csv << headers
       @time_sheets.each do |record|
        csv_data = []
        headers.each do |val|
          csv_data << record.send(csv_hash[val])
        end
        csv << csv_data
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=time_sheet.csv"
  end
  
   def build_time_sheet
    @start_date = params[:start_date] ?  Date.parse(params[:start_date]).beginning_of_day : start_of_month(Time.now.month.to_i)
    @end_date = params[:end_date] ? Date.parse(params[:end_date]).end_of_day : Time.now.end_of_day
    @customer_id = params[:customer_id] || []
    @user_id = params[:user_id] || []
    group_by_caluse = params[:group_by] || :ticket 
    group_by_caluse = group_by_caluse.to_sym()
    list_view_items = [:ticket , :customer_name , :note , :group_by_day_criteria ,:agent_name, :hours]
    @headers = list_view_items.delete_if{|item| item == group_by_caluse }
    @billable = (!params[:billable].blank? && !params[:billable].to_s.eql?("falsetrue")) ? [params[:billable].to_s.to_bool] : [true,false]
    @time_sheets = current_account.time_sheets.for_customers(@customer_id).by_agent(@user_id).created_at_inside(@start_date,@end_date).hour_billable(@billable).group_by(&group_by_caluse)
  end


end
