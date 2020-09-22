class HelpdeskReports::Export::PhoneSummary < HelpdeskReports::Export::Report
  include Reports::FreshfoneReport
  include Reports::Freshfone::SummaryReportsHelper
  include ReportsHelper

  def initialize(args, scheduled_report = false)
    args.symbolize_keys!
    args[:data_hash][:report_filters].map!{|filter| filter.update(filter){|k,v| k=='value' ? v.to_s : v }} if scheduled_report
    args = old_report_params(args)
    super
  end

  def build_export
    build_criteria
    set_filter
    @layout = "layouts/report/phone_summary_pdf.html.erb"

    #skip other process when there is no data. Return filepath as nil.
    return nil if @calls.empty? && @old_calls.empty?

    file = build_pdf
    build_file(file, file_format, report_type, PDF_EXPORT_TYPE)
  end

  def locals_option
    {
      :params => params,
      :calls => @calls,
      :old_calls => @old_calls
    }
  end

end