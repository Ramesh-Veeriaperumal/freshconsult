class HelpdeskReports::Response::Ticket::TicketList < HelpdeskReports::Response::Ticket::Base
  
  def process
    @processed_result = {}
    parse_list_result
    processed_result
  end
  
  private
  
  # def parse_list_result
  #   processed_result[:archive], processed_result[:non_archive] = [], []
  #   processed_result[:total_time] = {}
  #   raw_result.each do |row|
  #     if row["archive"] == "f"
  #       processed_result[:non_archive] << row[COLUMN_MAP[:ticket_id]].to_i
  #     else
  #       processed_result[:archive] << row[COLUMN_MAP[:ticket_id]].to_i
  #     end
  #     processed_result[:total_time][row['display_id'].to_i] = row['total_time'] if report_type.to_sym==:timespent
  #   end
  # end

  # hot fix to avoid missing archive tickets marked as non-archive
  def parse_list_result
    processed_result[:ticket_id] = []
    processed_result[:total_time] = {}
    raw_result.each { |row| processed_result[:ticket_id] << row[COLUMN_MAP[:ticket_id]].to_i }
    raw_result.each { |row| processed_result[:total_time][row['display_id'].to_i] = row['total_time'] } if report_type.to_sym==:timespent
  end
  
end