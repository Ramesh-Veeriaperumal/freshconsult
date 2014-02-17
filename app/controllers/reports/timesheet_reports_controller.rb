class Reports::TimesheetReportsController < ApplicationController
  
  include Reports::TimesheetReport
  include Reports::ReportTimes
  include ReadsToSlave
  
  before_filter :check_permission, :set_selected_tab
  before_filter :build_item ,  :only => [:index,:export_csv,:report_filter,:time_sheet_list]
  before_filter :time_sheet_list, :only => [:index,:report_filter]
  before_filter :time_sheet_for_export, :only => [:export_csv]

  
  def report_filter
    render :partial => "time_sheet_list"
  end
  
  def export_csv
    date_fields = ["Created at","Date"]
    csv_string = CSVBridge.generate do |csv|
      headers = csv_hash.keys.sort
      csv << headers
       @time_sheets.each do |record|
        csv_data = []
        headers.each do |val|
          if date_fields.include?(val)
            csv_data << parse_date(record.send(csv_hash[val]))
          else
            csv_data << record.send(csv_hash[val])
          end
        end
        csv << csv_data
      end
    end
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=time_sheet.csv"
  end
  
  def time_sheet_list
    @report_date = params[:date_range]
    @time_sheets = filter_with_groupby(@start_date,@end_date)    
    @time_sheet_data = billable_vs_non_billable(@time_sheets)
    stacked_chart_data
    previous_range_time_sheet #Fetching the previous time range data.
  end

  def previous_range_time_sheet
    #set the time (start/end) to previous range for comparison summary.
    set_time_range(true)
    old_time_sheets = filter_with_groupby(@start_time,@end_time)
    @old_time_sheet_data= billable_vs_non_billable(old_time_sheets)
  end
  
  def time_sheet_for_export
    @time_sheets = filter(@start_date,@end_date)
  end

  private
  
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

end
