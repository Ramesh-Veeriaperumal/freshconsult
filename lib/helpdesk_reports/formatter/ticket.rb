class HelpdeskReports::Formatter::Ticket
  
  attr_accessor :result, :report_type
  
  def initialize data, args
    @result = data
    @report_type = args[:report_type]
    @args = args
  end
  
  def format
    klass.new(result, @args).perform
  end
  
  def klass
    HelpdeskReports::Formatter::Ticket.const_get(report_type.classify)
  end

end