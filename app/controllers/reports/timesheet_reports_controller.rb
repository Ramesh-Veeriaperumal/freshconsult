class Reports::TimesheetReportsController < ApplicationController
  
   before_filter { |c| c.requires_permission :manage_tickets }
   before_filter :buidl_time_sheet, :only => [:index, :export_csv]
  
  def index
  end

 
  
  def export_csv
    csv_hash = {"Agent"=>"agent_name", "Hours"=>"hours_spent", "Date" =>"start_time" ,"Ticket Id"=>"ticket_display", "Note"=>"note"}
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
    billable = !params[:billable].blank? ? [params[:billable]] : [true,false]
    @time_sheets = obj.time_sheets.by_agent(@user_id).created_at_inside(start_of_month(@month.to_i),end_of_month(@month.to_i)).hour_billable(billable)
  end
  
    
  def valid_month?(time)
    time.is_a?(Numeric) && (1..12).include?(time)
  end
  
  def start_of_month(month=Time.current.month)
    Time.utc(Time.now.year, month, 1) if valid_month?(month)
  end
  
  def end_of_month(month)
    start_of_month(month).end_of_month
  end

end
