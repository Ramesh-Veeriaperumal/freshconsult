class Reports::TimesheetReportsController < ApplicationController
  
  include Reports::TimesheetReport
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :buidl_time_sheet, :only => [:index, :export_csv ,:report_filter]
  
  
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
  
  def buidl_time_sheet
    @month = params[:date] ? params[:date][:month] :Time.zone.now.month
    @customer_id = params[:customer_id].to_i() unless params[:customer_id].blank?
    @user_id = params[:user_id].to_i() unless params[:user_id].blank?
    obj = !@customer_id.blank? ? current_account.customers.find(@customer_id) : current_account
    @billable = (!params[:billable].blank?) ? [params[:billable].to_bool] : [true,false]
    @time_sheets = obj.time_sheets.by_agent(@user_id).created_at_inside(start_of_month(@month.to_i),end_of_month(@month.to_i)).hour_billable(@billable)
  end

end
