class HelpdeskReports::Export::ChatSummary < HelpdeskReports::Export::Report
  include HelpdeskReports::Helper::ControllerMethods

  def initialize(args, scheduled_report = false)
    args.symbolize_keys!
    args = old_report_params(args)
    super
  end

  def build_export
    @layout = "layouts/report/chat_summary_pdf.html.erb"
    file = build_pdf
    build_file(file, file_format, PDF_EXPORT_TYPE)
  end

  def locals_option
    {
      :params => params,
      :table_headers => get_chat_table_headers
    }
  end

end