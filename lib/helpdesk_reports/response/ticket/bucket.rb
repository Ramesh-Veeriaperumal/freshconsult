class HelpdeskReports::Response::Ticket::Bucket < HelpdeskReports::Response::Ticket::Base
  
  private 

  def process_metric
    return unless result_present? # Check if result is present or it is a No Data scenario  
    raw_result.each do |row|
      row.each do |bucketing, result|
        bucket_type, bucket = bucketing.split("|")
        processed_result[bucket_type] ||= {}
        processed_result[bucket_type][bucket] = result.to_i
      end
    end
  end
  
  def result_present?
    raw_result.first.values.reject{|v| v.to_i == 0}.present?
  end
  
end