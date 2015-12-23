class Reports::TimesheetReportsController < ApplicationController
  
  include Reports::TimesheetReport
  include ReadsToSlave
  helper AutocompleteHelper
  
  before_filter :check_permission, :set_selected_tab
  before_filter :build_item ,  :only => [:index,:export_csv,:report_filter,:time_sheet_list, :generate_pdf]
  before_filter :time_sheet_list, :only => [:index,:report_filter, :generate_pdf]
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
    @report_type = "timesheet_reports"
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

  def generate_pdf
    @report_title = t('adv_reports.time_sheet_report')
    render :pdf => @report_title, 
      :layout => 'report/timesheets_report_pdf.html', # uses views/layouts/pdf.haml
      :show_as_html => params[:debug].present?, # renders html version if you set debug=true in URL
      :template => 'sections/generate_report_pdf.pdf.erb',
      :page_size => "A3"
  end
  
  def time_sheet_for_export
    @time_sheets = filter(@start_date,@end_date)
    if Account.current.features?(:archive_tickets)
      @archive_time_sheets = archive_filter(@start_date,@end_date)
      @time_sheets = shift_merge_sorted_arrays(@time_sheets,@archive_time_sheets)
    end
  end

  private

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
