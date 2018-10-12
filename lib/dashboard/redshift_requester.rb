class Dashboard::RedshiftRequester

  include HelpdeskReports::Helper::Ticket
  
  REFRESH_FREQUENCY = 30

  def initialize(params, timeout = nil)
    @query_params = query_params params
    @timeout  = timeout  # Dashboard queries have 5 seconds
  end

  def fetch_records
    result = bulk_request(@query_params, true, @timeout)
    expiry = cache_expire_time result
    if error_in_response?(result)
      Rails.logger.info("Error in reports request :: #{result.inspect}")
      result = [error_message]
    end
    dump_time = last_redshift_dump_time(result)
    [result, expiry, dump_time]
  end

  private

  def query_params params
    if params.is_a? Array
      net_params = params.inject([]) do |cumulative, param|
        cumulative << { 'req_params' => req_params(param) }
        cumulative
      end
      net_params
    else
    [ { 'req_params' => req_params(params) }] 
    end
  end

  def req_params params
    default_query_params.merge(params.symbolize_keys)
  end

  def default_query_params
    req_params = {
      model:                  "TICKET",
      metric:                 "",
      group_by:               [],
      account_id:             Account.current.id,
      time_zone:              TimeZone.find_time_zone,
      date_range:             "",
      filter:                 [],
      time_trend:             false,
      time_trend_conditions:  [],
      dashboard:              true,
      refresh_frequency:      REFRESH_FREQUENCY
    }
  end

  def cache_expire_time received
    (received.present? && (received.last.is_a? Hash)&& received.last["last_dump_time"].present?) ? process_cache_expiry(received.last["last_dump_time"].to_i) : MemcacheKeys::DASHBOARD_TIMEOUT
  end

  def last_redshift_dump_time received
    (received.present? && (received.last.is_a? Hash) && received.last["last_dump_time"].present?) ? Time.at(received.last["last_dump_time"].to_i) : dashboard_cache_timeout.ago
  end

  def error_in_response? responses
    responses.select{|response| ((response.is_a? Hash) && response["errors"].present?)}.present?
  end

  def error_message
    {errors: I18n.t("helpdesk.realtime_dashboard.something_went_wrong")}
  end

  def process_cache_expiry dump_time
    remaining_time = (dashboard_cache_timeout.to_i - (Time.now.utc.to_i - dump_time.to_i))
    (remaining_time > MemcacheKeys::DASHBOARD_TIMEOUT) ? remaining_time : MemcacheKeys::DASHBOARD_TIMEOUT
  end

  def dashboard_cache_timeout
    REFRESH_FREQUENCY.minutes
  end

end
