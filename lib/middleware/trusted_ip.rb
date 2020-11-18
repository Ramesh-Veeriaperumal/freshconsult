class Middleware::TrustedIp

  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner", "signup", "email", "login"]
  SKIPPED_URL_PATHS = ['/api/cron/trigger_cron_api'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    env['CLIENT_IP'] ||= Rack::Request.new(env).ip()
    req_path = env['PATH_INFO']
    # Skip valid ip check if the request is from skipped subdomains
    return execute_request(env) if skipped_subdomain?(env)
    env['SHARD'] ||= ShardMapping.lookup_with_domain(env["SERVER_NAME"])
    # Skip valid ip check if the request is for nil shard.
    return execute_request(env) if (env['SHARD'].nil? or PodConfig['CURRENT_POD'] != env['SHARD'].pod_info) && !Rails.env.development?

    # Skip valid ip check if the request is for cron api.
    return execute_request(env) if SKIPPED_URL_PATHS.include?(req_path)

    # All requests other than api has to execute to set the user_credentials_id env var. Set by authlogic.
    # So that whitelisting can happen accordingly.
    # user_credentials_id won't be set in API request as it is not relied on authlogic.
    execute_request(env) unless api_request?(req_path)

    if env['SHARD'].present?
      is_robots_action = ['/robots', '/robots.txt', '/robots.text'].include?(req_path)
      unless is_robots_action
        raise AccountBlocked if env['SHARD'].blocked?
        raise DomainNotReady unless env['SHARD'].ok?
      end

      Sharding.run_on_shard(env['SHARD'].shard_name) do
        account_id = env['SHARD'].account_id
        if Account.current.try(:id) == account_id
          @current_account = Account.current
        else
          @current_account = Account.find(account_id)
          @current_account.make_current
        end
        return execute_request(env) if CustomRequestStore.read(:channel_api_request) || CustomRequestStore.read(:channel_v1_api_request)

        # Proceed only if user_credentials_id is present(i.e., authenticated user) or api request.
        if !env['rack.session']['user_credentials_id'].nil? || api_request?(req_path)
          if trusted_ips_enabled?
            current_ip = env['CLIENT_IP']
            Rails.logger.debug "Whitelisted IPS enabled: #{current_ip}"
            unless valid_ip(current_ip, env['rack.session']['user_credentials_id'], req_path)
              @status, @headers, @response = set_response(req_path, 403, "/unauthorized.html",
                                                          'Your IPAddress is blocked by the administrator')
              Rails.logger.error "Request from invalid ip for ip whitelisting enabled account. Account Id: #{@current_account.id}, IP: #{current_ip}"
              return [@status, @headers, @response]
            end
          end
        end
      end
    end

    # Execute api request only if it is from valid ip.
    execute_request(env) if api_request?(req_path)
    [@status, @headers, @response]

  rescue DomainNotReady, AccountBlocked => ex
      location_header = env['SHARD'].blocked? ? "/AccountBlocked.html" : "/DomainNotReady.html"
      error_message = env['SHARD'].blocked? ? 'Your account has been blocked' : 'Your data is getting moved to a new datacenter.'
      @status, @headers, @response = set_response(req_path, 404, location_header,
                                                  error_message)
      return [@status, @headers, @response]
    ensure
      Thread.current[:account] = nil 
      remove_instance_variable(:@whitelisted_ips) if defined?(@whitelisted_ips) # Should not retain the last requests's variables.
      remove_instance_variable(:@api_request) if defined?(@api_request) # Should not retain the last requests's variables.
  end

  def trusted_ips_enabled?
    @current_account.features_included?(:whitelisted_ips) && 
          (whitelisted_ips || {})[:enabled] 
  end

  def valid_ip(current_ip, current_user_id, req_path)
    # If api request, valid ip check should occur as both options in trusted_ip is applicable for agents.
    # If api is changed to accept customer login also, this should be changed.
    # For help_widget api request,
    # 1. if IP whitelisting is enabled only for agent, no IP range check is needed.
    # 2. if IP whitelisting is enabled for agents and customers, IP range check should be done.

    if widget_api_request?(req_path)
      return (whitelisted_ips.applies_only_to_agents ? true : ip_whitelisted?(current_ip))
    elsif api_request?(req_path) || trusted_ip_applicable_to_user?(current_user_id)
      return ip_whitelisted?(current_ip)
    else
      return true
    end
    return false
  end

  def ip_whitelisted?(current_ip)
    whitelisted_ips.ip_ranges.each do |ip|
      return true if ip_is_in_range?(IPAddress(ip[:start_ip]), IPAddress(ip[:end_ip]), IPAddress(current_ip))
    end
    false
  end

  # If applicable to only agents, check for agent login else customer login.
  def trusted_ip_applicable_to_user?(current_user_id)
    if whitelisted_ips.applies_only_to_agents  
      return @current_account.users.find_by_id(current_user_id).agent?
    else
      return true
    end
  end

  def ip_is_in_range?(start_ip, end_ip, current_ip)
    current_ip_version = current_ip.ipv4? ? "ipv4?" : "ipv6?"
    if start_ip.safe_send(current_ip_version) && end_ip.safe_send(current_ip_version)
      return true if current_ip >= start_ip && current_ip <= end_ip
    end
  end

  def set_response(req_path, api_status, location_header, message)
    if widget_api_request?(req_path)
      [api_status, { 'Content-type' => 'application/json' }, [error_hash(:ip_blocked, message)]]
    elsif api_request?(req_path)
      [api_status, { 'Content-type' => 'application/json' }, [{ message: message }.to_json]]
    else
      [302, { 'Location' => location_header }, [message]]
    end
  end

  # Will return whitelisted_ip from cache. Only one call to memcache for one request.
  def whitelisted_ips
    return @whitelisted_ips if defined?(@whitelisted_ips) # To avoid getting queried to memcache if it returns nil
    @whitelisted_ips ||= @current_account.whitelisted_ip_from_cache.first
  end

  def api_request?(req_path)
    return @api_request if defined?(@api_request) # To avoid getting manipulated again if api_request returns false
    @api_request ||= req_path.starts_with?('/api/')
  end

  def widget_api_request?(req_path)
    req_path.starts_with?('/api/widget/')
  end

  def execute_request(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end

  def skipped_subdomain?(env)
    SKIPPED_SUBDOMAINS.include?(env["HTTP_HOST"].split(".")[0]) 
  end

  def error_hash(code = nil, message = '')
    { code: code, message: message }.to_json
  end
end
