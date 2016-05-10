class HelpdeskReports::Formatter::Ticket
  
  attr_accessor :result, :report_type
  
  def initialize data, args
    @result = data
    @args   = args
    @report_type = args[:report_type]
  end
  
  def format
    klass.new(result, @args).perform
  end
  
  def klass
    "HelpdeskReports::Formatter::Ticket::#{report_type.to_s.classify}".constantize
  end

end