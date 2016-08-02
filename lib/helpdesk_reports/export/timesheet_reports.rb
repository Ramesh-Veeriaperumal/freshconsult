class HelpdeskReports::Export::TimesheetReports < HelpdeskReports::Export::Report
  include Reports::TimesheetReport

  ARRAY_METRICS = [:user_id, :group_id, :ticket_type, :products_id, :priority, :customers_filter]

  def initialize(args, scheduled_report = false)
    args.symbolize_keys!
    args = old_report_params(args)
    super
  end

  def build_export
    params[:group_by] = params[:group_by_field]
    params.delete(:group_by_field)
    params[:customers] = params[:customers_filter]
    params.delete(:customers_filter)
    params.each { |key,value| params[key] = value.to_s.split(",") if ARRAY_METRICS.include?(key.to_sym) && value }
    build_item
    time_sheet_list

    #skip other process when there is no data. Return filepath as nil.
    return nil if (no_data?(@time_sheet_data) && no_data?(@old_time_sheet_data))

    @layout = "layouts/report/timesheet_reports_pdf.html.erb"
    file = build_pdf
    build_file(file, file_format, report_type, PDF_EXPORT_TYPE)
  end

  def locals_option
    {
      :params => params,
      :time_sheets => @time_sheets,
      :report_date => params[:date_range],
      :time_sheet_data => @time_sheet_data,
      :old_time_sheet_data => @old_time_sheet_data,
      :activity_data_hash => @activity_data_hash,
      :headers => @headers
    }
  end
  
  def no_data? data_hash
    data_hash.values.uniq == [0.0]
  end

end