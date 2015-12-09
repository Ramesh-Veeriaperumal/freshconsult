class Middleware::TrustedIp

  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login"] 

  def initialize(app)
    @app = app
  end

  def call(env)
    env['CLIENT_IP'] ||= Rack::Request.new(env).ip()
    req_path = env['PATH_INFO']
    @status, @headers, @response = @app.call(env)
    return [@status, @headers, @response] if SKIPPED_SUBDOMAINS.include?(env["HTTP_HOST"].split(".")[0])
    shard = ShardMapping.lookup_with_domain(env["HTTP_HOST"])
    return [@status, @headers, @response] if shard.nil? && !Rails.env.development?
    account_id =  Rails.env.development? ? Account.first.id : shard.account_id
    Sharding.select_shard_of(account_id) do
      @current_account = Account.find(account_id)
      Thread.current[:account] = @current_account
      unless env['rack.session']['user_credentials_id'].nil?
        if trusted_ips_enabled?
          unless valid_ip(env['CLIENT_IP'], env['rack.session']['user_credentials_id'])
            @status, @headers, @response = set_response(req_path, 403, "/unauthorized.html",
                                                        'Your IPAddress is blocked by the administrator')
            return [@status, @headers, @response]
          end
        end
      end
    end
    [@status, @headers, @response]
    rescue DomainNotReady => ex
      @status, @headers, @response = set_response(req_path, 404, "/DomainNotReady.html", 
                                                  'Your data is getting moved to a new datacenter.')
      return [@status, @headers, @response]
    ensure
      Thread.current[:account] = nil
  end

  def trusted_ips_enabled?
    @current_account.features_included?(:whitelisted_ips) && 
          (@current_account.whitelisted_ip_from_cache || {})[:enabled] 
  end

  def valid_ip(current_ip, current_user_id)
    unless applies_to_agent?(current_user_id)
      @current_account.whitelisted_ip_from_cache.ip_ranges.each do |ip|
        return true if ip_is_in_range?(IPAddress(ip[:start_ip]),IPAddress(ip[:end_ip]),IPAddress(current_ip))
      end
    else
      return true
    end
    return false
  end

  def applies_to_agent?(current_user_id)
    @current_account.whitelisted_ip_from_cache.applies_only_to_agents && 
           !@current_account.users.find_by_id(current_user_id).agent? 
  end

  def ip_is_in_range?(start_ip, end_ip, current_ip)
    current_ip_version = current_ip.ipv4? ? "ipv4?" : "ipv6?"
    if start_ip.send(current_ip_version) && end_ip.send(current_ip_version)
      return true if current_ip >= start_ip && current_ip <= end_ip
    end
  end

  def set_response(req_path, api_status, location_header, message)
    if req_path.starts_with?('/api/')
      return [api_status, {"Content-type" => "application/json"}, [{message: message}.to_json]]
    else
      return [302, {"Location" => location}, [message]]
    end
  end

end

