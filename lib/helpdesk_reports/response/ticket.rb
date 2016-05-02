class HelpdeskReports::Response::Ticket
  include HelpdeskReports::Constants
  
  attr_accessor :result, :metric, :query_type
  
  def initialize result, params, query_type, report_type, pdf_export = false
    @result     = result
    @metric     = params[:metric]
    @query_type = query_type
    @date_range = params[:date_range]
    @report_type = report_type
    @pdf_export = pdf_export
  end
  
  def parse_result
    result["errors"].present? ? error_result : query_result
  end
    
  private
  
  def error_result
    { "errors" => result["errors"]}
  end
  
  def query_result
    klass(parser_type).new(result["result"], @date_range, @report_type, query_type, @pdf_export).process
  end
  
  def parser_type
    METRIC_TO_QUERY_TYPE[query_type]
  end
  
  def klass(query_type)
    "HelpdeskReports::Response::Ticket::#{query_type}".constantize
  end
  
end