class HelpdeskReports::Response::Ticket::Bucket < HelpdeskReports::Response::Ticket::Base
  
  private 

  def process_metric
    raw_result.each do |row|
      row.each do |bucketing, result|
        bucket_type, bucket = bucketing.split("|")
        processed_result[bucket_type] ||= {}
        processed_result[bucket_type][bucket] = result.to_i
      end
    end
  end
  
end