class HelpdeskReports::ParamConstructor::PerformanceDistribution < HelpdeskReports::ParamConstructor::Base

  METRICS_WITH_BUCKETS = {
      "AVG_RESPONSE_TIME" => ["response_time"],
      "AVG_FIRST_RESPONSE_TIME" => ["first_response_time"],
      "AVG_RESOLUTION_TIME" => ["resolution_time"],
    }

  def initialize options
    @report_type = :performance_distribution
    @trend_conditions = ["doy", "w", "mon", "qtr", "y"]
    super options
  end

  def build_params
    query_params
  end

  def query_params
    METRICS_WITH_BUCKETS.keys.inject([]) do |params, metric|
      query = basic_param_structure
      
      time_trend_query = query.clone
      time_trend_query[:metric] = metric
      time_trend_query[:time_trend] = true
      time_trend_query[:time_trend_conditions] = @trend_conditions.uniq
      params << time_trend_query

      bucket_query = query.clone
      bucket_query[:metric] = metric
      bucket_query[:bucket] = true
      bucket_query[:bucket_conditions] = METRICS_WITH_BUCKETS[metric]
      params << bucket_query
    end
  end

end