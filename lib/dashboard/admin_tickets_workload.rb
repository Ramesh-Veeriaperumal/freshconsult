class Dashboard::AdminTicketsWorkload < Dashboard
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

  def fetch_results_by_source
    cache_result_by_source
  end

  private

  def date_range
    redshift_custom_date_format Time.zone.now.beginning_of_day  
  end

  def format_params
    @req_params[:date_range]              = date_range
    @req_params[:metric]                  = METRIC
    @req_params[:time_trend]              = true
    @req_params[:time_trend_conditions]   = ["h"]
    @req_params[:group_id]                = group_id_param if group_id_param.present?
    @req_params[:filter]                  = handle_redshift_filters
  end

  def cache_result
    redshift_cache_data DASHBOARD_REDSHIFT_WORKLOAD, "process_results"
  end

  def cache_result_by_source
    redshift_cache_data DASHBOARD_REDSHIFT_WORKLOAD_BY_SOURCE, "process_results_by_source"
  end

  def process_results
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).admin_tickets_workload, expiry]
  end

  def process_results_by_source
    @req_params[:group_by] = ["source"]
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).admin_channel_workload, expiry]
  end

  def group_id_array
    @req_params["group_id"].blank? ? [] : @req_params["group_id"].split(",")
  end

end