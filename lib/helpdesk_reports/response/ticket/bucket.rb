class HelpdeskReports::Response::Ticket::Bucket < HelpdeskReports::Response::Ticket::Base
  
  private 

  def process_metric
    return unless result_present? # Check if result is present or it is a No Data scenario
    buckets = Set.new
    processed_result["tickets_count"] = {}
    raw_result.each do |row|
      row.each do |bucketing, result|
        bucket_type, bucket = bucketing.split("|")
        buckets << bucket_type
        
        processed_result[bucket_type] ||= {}
        processed_result[bucket_type][bucket] = result.to_i
        
        processed_result["tickets_count"][bucket_type] ||= 0
        processed_result["tickets_count"][bucket_type]  += result.to_i
      end
    end
    add_bucket_value_map(buckets)
    average_interactions(buckets) if report_type.downcase == :glance   #remove downcase once scheduled reports is implemented
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
  #total_interactions is calculated by aggregating the product of no. of responses and no. of tickets for each response
  #average interactions = total_interactions/timerange.  Average is being displayed as a float value
  def average_interactions buckets
    processed_result["average_interactions"] = Hash.new(0)
    total_interactions = Hash.new(0)
    buckets.each do |bucket_type|
      ReportsAppConfig::BUCKET_QUERY[bucket_type.to_sym].each do |bucket|
        total_interactions[bucket_type] += processed_result[bucket_type][bucket['label'].to_s] * bucket['value'] 
      end
      if processed_result["tickets_count"][bucket_type] != 0
        processed_result["average_interactions"][bucket_type] = 
            (total_interactions[bucket_type].to_f / processed_result["tickets_count"][bucket_type]).round(1) 
      end
    end
  end
  
end