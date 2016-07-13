class HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Constants
  include HelpdeskReports::Util::Ticket
  include HelpdeskReports::Helper::ReportsHelper

  attr_accessor :raw_result, :processed_result, :date_range, :report_type, :start_date, :end_date

  def initialize result, date_range, report_type, query_type, pdf_export
    @raw_result       = result
    @date_range       = date_range
    @report_type      = report_type
    @query_type       = query_type
    @pdf_export       = pdf_export
    dates             = date_range.split("-")
    @start_date       = Date.parse(dates.first)
    @end_date         = dates.length > 1 ?  Date.parse(dates.second) : start_date   
    @processed_result = {}
  end

  def process
    process_metric if raw_result.present? # return empty hash if ZERO sql rows
    sort_group_by_values if @pdf_export
    map_field_ids_to_values
    processed_result
  end
  
end
