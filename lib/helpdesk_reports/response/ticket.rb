class HelpdeskReports::Response::Ticket
  include HelpdeskReports::Constants::Ticket
  
  attr_accessor :result, :metric, :query_type, :date_range
  
  def initialize result, params, query_type, report_type
    @result     = result
    @metric     = params[:metric]
    @query_type = query_type
    @date_range = params[:date_range]
    @report_type = report_type
  end
  
  def parse_result
    @result["errors"].present? ? error_result : query_result
  end
    
  private
  
  def error_result
    { "error" => result["errors"]}
  end
  
  def query_result
    klass(parser_type).new(result["result"], date_range, @report_type).process
  end
  
  def parser_type
    METRIC_TO_QUERY_TYPE[query_type]
  end
  
  def klass(query_type)
    HelpdeskReports::Response::Ticket.const_get(query_type)
  end
  
end