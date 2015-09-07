class HelpdeskReports::Formatter::Ticket
  
  attr_accessor :result, :report_type
  
  def initialize data, report
    @result = data
    @report_type = report
  end
  
  def format
    klass.new(result).perform
  end
  
  def klass
    HelpdeskReports::Formatter::Ticket.const_get(report_type.classify)
  end

end