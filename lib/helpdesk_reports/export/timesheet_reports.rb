class HelpdeskReports::Export::TimesheetReports < HelpdeskReports::Export::Report
  include Reports::TimesheetReport

  ARRAY_METRICS = [:user_id, :group_id, :ticket_type, :products_id, :priority, :customers_filter]
  CSV_BREAK_COLUMN_LIMIT = 12
  PDF_ORIENTATION_BREAK_LIMIT = 8

  def initialize(args, scheduled_report = false)
    args.symbolize_keys!
    args = old_report_params(args)
    args[:columns] = args[:data_hash][:columns] if args[:data_hash].present?

    columns =  args[:columns] || []
    @columns_length = columns.length + ( Account.current.products.any? ? 7 : 6 ) #default columns
    if(@columns_length > CSV_BREAK_COLUMN_LIMIT)
      args[:file_format] = TYPES[:csv]
      @pdf_export = false
    else
      args[:file_format] = TYPES[:pdf]
      @pdf_export = true
    end
    super
  end

  def build_export
    if(params[:group_by_field].present?)
      params[:group_by] = params[:group_by_field]
      params.delete(:group_by_field)
    end

    if(params[:customers_filter].present?)
      params[:company_id] = params[:customers_filter]
      params.delete(:customers_filter)
    end
    # params.each { |key,value| params[key] = value.to_s.split(",") if ARRAY_METRICS.include?(key.to_sym) && value }

    params[:report_filters].each { |f_h| f_h.symbolize_keys! }
    build_item
    if @pdf_export
      build_master_column_header_hash
      time_sheet_list_pdf
      #skip other process when there is no data. Return filepath as nil.
      return nil if no_data?(@metric_data)
      @layout = 'layouts/report/timesheet_reports_pdf.html.erb'
      file = build_pdf( @columns_length > PDF_ORIENTATION_BREAK_LIMIT )
      build_file(file, file_format, report_type, PDF_EXPORT_TYPE)
    else
      time_sheet_for_export
      return nil if @time_sheets.blank?
      build_file(construct_csv_string, file_format, report_type, CSV_EXPORT_TYPE)
    end

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
      :load_time => @load_time,
      :master_column_header_hash => @master_column_header_hash,
      :total_time => @total_time
    }
  end

  def no_data? data_hash
    has_data = false
    data_hash.values.each { |hash| has_data ||= (hash.values.uniq != [0.0]) }
    !has_data
  end

end
