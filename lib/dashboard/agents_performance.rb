class Dashboard::AgentsPerformance < Dashboard
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
    redshift_custom_date_format Time.zone.now.beginning_of_day  
  end

  def format_params
    @req_params[:metric]     = METRIC 
    @req_params[:group_by]   = ["agent_id"]
    @req_params[:date_range] = date_range
    @req_params[:group_id]   = group_id_param if group_id_param.present?
    @req_params[:filter]     = handle_redshift_filters   
  end

  def cache_result
    redshift_cache_data DASHBOARD_REDSHIFT_AGENT_PERFORMANCE, "process_results"
  end

  def cache_result_summary
    redshift_cache_data DASHBOARD_REDSHIFT_AGENT_PERFORMANCE_SUMMARY, "process_results_summary"
  end

  def process_results
    received, expiry, dump_time = Dashboard::RedshiftRequester.new(@req_params).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    result = received[0]
    data = result["result"]
    [Dashboard::RedshiftResponseParser.new(data, {group_id: group_id_array, dump_time: dump_time}).supervisor_agent_received_resolved, expiry]
  end

  def process_results_summary
    @req_params[:metric] = "AGENT_SUMMARY_CURRENT"
    agent_summary_params = @req_params.deep_dup
    glance = Dashboard::GlanceCurrent.new(@req_params)
    total_summary_params = glance.fetch_total_results_for_supervisor
    received, expiry, dump_time = Dashboard::RedshiftRequester.new([agent_summary_params, total_summary_params]).fetch_records
    return redshift_error_response if is_redshift_error?(received)
    agent_summary = received[0]
    total_summary = received[1]
    agent_data = agent_summary["result"]
    total_data = total_summary["result"]
    processed_agent = Dashboard::RedshiftResponseParser.new(agent_data, {group_id: group_id_array, dump_time: dump_time}).agents_summary
    processed_total = Dashboard::RedshiftResponseParser.new(total_data).transform_glance_data
    [{"total" => processed_total}.merge(processed_agent), expiry]
  end

  def group_id_array
    @req_params["group_id"].blank? ? [] : @req_params["group_id"].split(",")
  end

end