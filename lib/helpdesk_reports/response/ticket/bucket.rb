class HelpdeskReports::Response::Ticket::Bucket < HelpdeskReports::Response::Ticket::Base
  
  private 

  def process_metric
    return unless result_present? # Check if result is present or it is a No Data scenario
    buckets = Set.new
    processed_result["tickets_count"] = {}
    total_interaction_count = {}
    raw_result.each do |row|
      row.each do |bucketing, result|
        bucket_type, bucket = bucketing.split("|")
        if bucket == "total_count"
          total_interaction_count[bucket_type] = result.to_i
          next
        elsif bucket == "avg_value"
          processed_result["avg_value"] = result.to_i
          next
        end
        buckets << bucket_type
        
        processed_result[bucket_type] ||= {}
        processed_result[bucket_type][bucket] = result.to_i
        
        processed_result["tickets_count"][bucket_type] ||= 0
        processed_result["tickets_count"][bucket_type]  += result.to_i
      end
    end
    add_bucket_value_map(buckets)
    average_interactions(buckets, total_interaction_count) if report_type == :glance
  end
  
  def result_present?
    raw_result.first.values.reject{|v| v.to_i == 0}.present?
  end
  
  def add_bucket_value_map buckets
    processed_result["value_map"] = {}
    buckets.each do |bucket_type|
      processed_result["value_map"][bucket_type] =  ReportsAppConfig::BUCKET_QUERY[bucket_type.to_sym].collect do |bucket|
                                                      values = bucket.values
                                                      [values[2], [values[1],values[0]]]
                                                    end.to_h
    end
  end

  #calculates average for agent and customer responses
  #average interactions = total_interaction_count/ticket_count.  Average is displayed as a float value
  def average_interactions buckets, total_interaction_count
    processed_result["average_interactions"] = Hash.new(0)
    buckets.each do |bucket_type|
      processed_result["average_interactions"][bucket_type] =
          (total_interaction_count[bucket_type].to_f / processed_result["tickets_count"][bucket_type]).round(1) if processed_result["tickets_count"][bucket_type] != 0
    end
  end
  
end