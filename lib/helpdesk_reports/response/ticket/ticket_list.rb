class HelpdeskReports::Response::Ticket::TicketList < HelpdeskReports::Response::Ticket::Base
  
  def process
    @processed_result = {}
    parse_list_result
    processed_result
  end
  
  private
  
  def parse_list_result
    processed_result[:archive], processed_result[:non_archive] = [], []
    raw_result.each do |row|
      if row["archive"] == "f"
        processed_result[:non_archive] << row[COLUMN_MAP[:ticket_id]].to_i
      else
        processed_result[:archive] << row[COLUMN_MAP[:ticket_id]].to_i
      end
    end
  end
  
end