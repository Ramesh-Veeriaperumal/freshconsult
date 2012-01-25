class Reports::TimesheetReportsController < ApplicationController
  
  include Reports::TimesheetReport
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_selected_tab
  before_filter :build_item ,  :only => [:index,:export_csv,:report_filter]
  before_filter :time_sheet_list, :only => [:index,:report_filter]
  before_filter :time_sheet_for_export, :only => [:export_csv]

  
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
  
   def time_sheet_list
     @time_sheets = current_account.time_sheets.for_customers(@customer_id).by_agent(@user_id).created_at_inside(@start_date,@end_date).hour_billable(@billable).group_by(&group_by_caluse)
   end
  
  def time_sheet_for_export
     @time_sheets = current_account.time_sheets.for_customers(@customer_id).by_agent(@user_id).created_at_inside(@start_date,@end_date).hour_billable(@billable)
  end



end
