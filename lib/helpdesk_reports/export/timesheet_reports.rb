class HelpdeskReports::Export::TimesheetReports < HelpdeskReports::Export::Report
  include Reports::TimesheetReport

  ARRAY_METRICS = [:user_id, :group_id, :ticket_type, :products_id, :priority, :customers_filter]

  def initialize(args, scheduled_report = false)
    args.symbolize_keys!
    args = old_report_params(args)
    @pdf_export = true
    super
  end

  def build_export
    params[:group_by] = params[:group_by_field]
    params.delete(:group_by_field)
    params[:customers] = params[:customers_filter]
    params.delete(:customers_filter)
    params.each { |key,value| params[key] = value.to_s.split(",") if ARRAY_METRICS.include?(key.to_sym) && value }
    build_item
    time_sheet_list_pdf

    #skip other process when there is no data. Return filepath as nil.
    return nil if no_data?(@metric_data)

    @layout = "layouts/report/timesheet_reports_pdf.html.erb"
    file = build_pdf
    build_file(file, file_format, report_type, PDF_EXPORT_TYPE)
  end

  def locals_option
    {
      :params => params,
      :time_sheets => @time_sheets,
      :report_date => params[:date_range],
      :metric_data => @metric_data,
      :activity_data_hash => @activity_data_hash,
      :headers => @headers,
      :group_count => @group_count,
      :group_names => @group_names,
      :load_time => @load_time
    }
  end
  
  def no_data? data_hash
    has_data = false
    data_hash.values.each { |hash| has_data ||= (hash.values.uniq != [0.0]) }
    !has_data
  end

end