class Middleware::TrustedIp

  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login"] 

  def initialize(app)
    @app = app
  end

  def call(env)
    env['CLIENT_IP'] ||= Rack::Request.new(env).ip()
    req_path = env['PATH_INFO']

    # Skip valid ip check if the request is from skipped subdomains
    return execute_request(env) if skipped_subdomain?(env)
    shard = ShardMapping.lookup_with_domain(env["HTTP_HOST"])

    # Skip valid ip check if the request is for nil shard.
    return execute_request(env) if shard.nil? && !Rails.env.development?

    # All requests other than api has to execute to set the user_credentials_id env var. Set by authlogic.
    # So that whitelisting can happen accordingly.
    # user_credentials_id won't be set in API request as it is not relied on authlogic.
    execute_request(env) unless api_request?(req_path)
    
    account_id =  Rails.env.development? ? Account.first.id : shard.account_id
    Sharding.select_shard_of(account_id) do
      @current_account = Account.find(account_id)
      @current_account.make_current
      # Proceed only if user_credentials_id is present(i.e., authenticated user) or api request.
      if !env['rack.session']['user_credentials_id'].nil? || api_request?(req_path)
        if trusted_ips_enabled?
          unless valid_ip(env['CLIENT_IP'], env['rack.session']['user_credentials_id'], req_path)
            @status, @headers, @response = set_response(req_path, 403, "/unauthorized.html",
                                                        'Your IPAddress is blocked by the administrator')
            return [@status, @headers, @response]
          end
        end
      end
    end

    # Execute api request only if it is from valid ip.
    execute_request(env) if api_request?(req_path)
    [@status, @headers, @response]

    rescue DomainNotReady => ex
      @status, @headers, @response = set_response(req_path, 404, "/DomainNotReady.html", 
                                                  'Your data is getting moved to a new datacenter.')
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
    if api_request?(req_path) || trusted_ip_applicable_to_user?(current_user_id)
      whitelisted_ips.ip_ranges.each do |ip|
        return true if ip_is_in_range?(IPAddress(ip[:start_ip]),IPAddress(ip[:end_ip]),IPAddress(current_ip))
      end
    else
      return true
    end
    return false
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
    if start_ip.send(current_ip_version) && end_ip.send(current_ip_version)
      return true if current_ip >= start_ip && current_ip <= end_ip
    end
  end

  def set_response(req_path, api_status, location_header, message)
    if api_request?(req_path)
      return [api_status, {"Content-type" => "application/json"}, [{message: message}.to_json]]
    else
      return [302, {"Location" => location_header}, [message]]
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

  def execute_request(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end

  def skipped_subdomain?(env)
    SKIPPED_SUBDOMAINS.include?(env["HTTP_HOST"].split(".")[0]) 
  end

end

