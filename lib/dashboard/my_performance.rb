class Dashboard::MyPerformance < Dashboard
  include Cache::Memcache::Dashboard::CacheData
  include MemcacheKeys

  METRIC = "DASHBOARD_RECEIVED_RESOLVED_TICKETS"

  def initialize params
    @req_params = params
    format_params
  end

  def fetch_results
    cache_result
  end

  def fetch_results_summary
    cache_result_summary
  end

  private

  def date_range
    redshift_custom_date_format ([Time.zone.now.beginning_of_month, Time.zone.now.end_of_month])
  end

  def format_params
    @req_params[:metric]                  = METRIC
    @req_params[:date_range]              = date_range
    @req_params[:time_trend]              = true
    @req_params[:time_trend_conditions]   = ["doy", "dow"]
    @req_params[:filter]                  = handle_redshift_filters({include_user: true})
  end

  def cache_result
    redshift_cache_data DASHBOARD_REDSHIFT_MY_PERFORMANCE, "process_results"
  end

  def cache_result_summary
    redshift_cache_data DASHBOARD_REDSHIFT_MY_PERFORMANCE_SUMMARY, "process_results_summary"
  end

  def process_results
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).agent_received_resolved, expiry]
  end

  def process_results_summary
    glance = Dashboard::GlanceCurrent.new(@req_params.deep_dup)
    user_params = glance.fetch_results_by_user

    month_params, week_params = glance.fetch_total_results_by_user
    result, expiry, dump_time = Dashboard::RedshiftRequester.new([user_params, month_params, week_params]).fetch_records
    return redshift_error_response if is_redshift_error?(result)
    user_summary, month_summary, week_summary = result[0]["result"], result[1]["result"], result[2]["result"]
    user_summary = Dashboard::RedshiftResponseParser.new(user_summary).transform_glance_data
    week_summary = Dashboard::RedshiftResponseParser.new(week_summary).transform_glance_data
    month_summary = Dashboard::RedshiftResponseParser.new(month_summary).transform_glance_data
    user_summary = Dashboard::RedshiftResponseParser.new(user_summary, {dump_time: dump_time}).agent_summary 
    data_summary = { "total" => {
      "week" => week_summary,
      "month" => month_summary
      }}.merge(user_summary)   
    [data_summary, expiry]
  end

  def group_id_array
    @req_params["group_id"].blank? ? [] : @req_params["group_id"].split(",")
  end

end