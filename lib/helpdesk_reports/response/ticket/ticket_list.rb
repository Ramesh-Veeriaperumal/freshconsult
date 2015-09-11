class HelpdeskReports::Response::Ticket::TicketList < HelpdeskReports::Response::Ticket::Base

  def initialize result, date_range, report_type
    super(result, date_range, report_type)
    @processed_result = []
  end
  
  def process
    parse_list_result
    processed_result
  end
  
  private
  
  def parse_list_result
    raw_result.each do |row|
      processed_result << row[COLUMN_MAP[:ticket_id]]
    end
  end
  
end