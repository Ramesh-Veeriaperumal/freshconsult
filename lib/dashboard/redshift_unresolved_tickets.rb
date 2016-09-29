class Dashboard::RedshiftUnresolvedTickets < Dashboard
  include Cache::Memcache::Dashboard::CacheData
  include MemcacheKeys

  METRIC = "UNRESOLVED_TICKETS"

  def initialize params
    @req_params = params
    format_params
  end

  def fetch_agent_unresolved
    cache_agent_unresolved
  end

  def fetch_customer_unresolved
    cache_customer_unresolved
  end

  private

  def date_today
    redshift_custom_date_format Time.zone.now
  end

  def date_range
    redshift_custom_date_format 1.week.ago.in_time_zone(Time.zone.name)
  end

  def cache_agent_unresolved
    redshift_cache_data DASHBOARD_REDSHIFT_TOP_AGENTS, "process_agent_unresolved"
  end

  def cache_customer_unresolved
    redshift_cache_data DASHBOARD_REDSHIFT_TOP_CUSTOMERS, "process_customer_unresolved"
  end

  def process_agent_unresolved
    @req_params[:group_by]    = ["agent_id"]
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).agent_unresolved, expiry]
  end

  def process_customer_unresolved
    @req_params[:group_by]    = ["requester_id"]
    @req_params[:date_range]  = date_today
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"] 
    [Dashboard::RedshiftResponseParser.new(data, {dump_time: dump_time}).customer_unresolved, expiry]
  end

  def format_params
    @req_params[:metric]                  = METRIC
    @req_params[:date_range]              = date_range
    @req_params[:sorting]                 = true
    @req_params[:sorting_conditions]      = "DESC"
    @req_params[:group_id]                = group_id_param if group_id_param.present?
    @req_params[:filter]                  = handle_redshift_filters
  end

end