class HelpdeskReports::ParamConstructor::PerformanceDistribution < HelpdeskReports::ParamConstructor::Base

  METRICS_WITH_BUCKETS = {
      "AVG_RESPONSE_TIME" => ["response_time"],
      "AVG_FIRST_RESPONSE_TIME" => ["first_response_time"],
      "AVG_RESOLUTION_TIME" => ["resolution_time"],
    }

  DAY_TOGGLE =['this_week','previous_week','last_7','last_30','this_month','previous_month']
  
  def initialize options
    @report_filter_params = options
    @report_type = :performance_distribution
    @trend_conditions = ["doy", "w", "mon", "qtr", "y"]
    super options
  end

  def build_params
    query_params
  end

  def query_params
    dr = @date_range.split("-")
    single_day_date_range = (dr.size == 1) || (dr[0].strip == dr[1].strip) #for one day time range, only bucket query is needed.
    
    unless single_day_date_range
      if basic_param_structure[:scheduled_report]  
        conditions = @report_filter_params[:date]["period"] || @report_filter_params[:date]["date_range"]
        @trend_conditions =   case conditions
                              when  *DAY_TOGGLE, 6, 29
                                options[:resolution_trend] = options[:response_trend] = options[:trend] = "doy"
                                ["doy","y"]
                              else 
                                options[:resolution_trend] = options[:response_trend] = options[:trend] = "mon"
                                ["mon","y"]
                              end  
      end 
    end

    METRICS_WITH_BUCKETS.keys.inject([]) do |params, metric|
      query = basic_param_structure
      unless single_day_date_range
        time_trend_query = query.clone
        time_trend_query[:metric] = metric
        time_trend_query[:time_trend] = true
        time_trend_query[:time_trend_conditions] = @trend_conditions.uniq
        params << time_trend_query
      end

      bucket_query = query.clone
      bucket_query[:metric] = metric
      bucket_query[:bucket] = true
      bucket_query[:bucket_conditions] = METRICS_WITH_BUCKETS[metric]
      bucket_query[:query_with_avg] = true if single_day_date_range #for one day time range, average value is passed in bucket query result.
      params << bucket_query
    end
  end

end