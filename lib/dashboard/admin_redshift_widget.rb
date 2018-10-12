class Dashboard::AdminRedshiftWidget < Dashboards
  include Cache::Memcache::Dashboard::CacheData
  include MemcacheKeys

  DASHBOARD_METRICS = "DASHBOARD_METRICS"
  DASHBOARD_TRENDS  = "DASHBOARD_TRENDS"

  REPORTS_TIMEOUT = 5

  attr_accessor :req_params

  def initialize params
    @req_params = params.slice("group_id", "product_id")
    format_params
  end

  def fetch_dashboard_metrics
    cache_result
  end

  def fetch_dashboard_trends
    cache_trends_result
  end

  private

  def date_range
    redshift_custom_date_format Time.zone.now.beginning_of_day
  end

  def format_params
    req_params[:date_range]              = date_range
    req_params[:metric]                  = DASHBOARD_METRICS
    req_params[:time_trend]              = false
    req_params[:time_trend_conditions]   = []
    req_params[:group_id]                = group_id_param if group_id_param.present?
    req_params[:product_id]              = product_id_param if product_id_param.present?
    req_params[:filter]                  = handle_redshift_filters
    req_params[:reference]               = false
  end

  def cache_result
    redshift_cache_data DASHBOARD_V2_METRICS, "process_results", "redshiftv2_cache_identifier"
  end

  def cache_trends_result
    redshift_cache_data DASHBOARD_V2_TRENDS, "process_trends_results", "redshiftv2_cache_identifier"
  end

  def process_results
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(req_params, REPORTS_TIMEOUT).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).dashboard_v2_metrics, expiry]
  end

  def process_trends_results
    req_params[:metric]                   = DASHBOARD_TRENDS
    req_params[:time_trend]               = true
    req_params[:time_trend_conditions]    = ['h']
    req_params[:reference]                = true
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(req_params, REPORTS_TIMEOUT).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).dashboard_v2_trends, expiry]
  end

  def product_id_param
    return nil if req_params["product_id"].blank?
    req_params["product_id"].is_a?(Array) ? req_params["product_id"].join(",") : req_params["product_id"]
  end

  def group_id_param
    return nil if req_params["group_id"].blank? && !User.current.group_ticket_permission
    @req_params["group_id"] = user_agent_groups.join(",") if User.current.group_ticket_permission && req_params["group_id"].blank?
    req_params["group_id"].is_a?(Array) ? req_params["group_id"].join(",") : req_params["group_id"]
  end

end