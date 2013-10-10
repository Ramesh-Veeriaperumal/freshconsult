class Middleware::TrustedIp

  def initialize(app)
    @app = app
  end

  def call(env)
    shard = ShardMapping.lookup_with_domain(env["HTTP_HOST"])
    raise DomainNotReady unless shard || !Rails.env.production?
    account_id =  Rails.env.development? ? Account.first.id : shard.account_id
    Sharding.select_shard_of(account_id) do
      @current_account = Account.find(account_id)
      Thread.current[:account] = @current_account
      unless env['rack.session']['user_credentials_id'].nil?
        if trusted_ips_enabled?
          unless valid_ip(env['REMOTE_ADDR'], env['rack.session']['user_credentials_id'])
            @status, @headers, @response = [302, {"Location" => "/unauthorized.html"}, 
                                        'Your IPAddress is bocked by the administrator']
            return [@status, @headers, @response]
          end
        end
      end
    end
    @status, @headers, @response = @app.call(env)
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
      return true if (start_ip..end_ip) === current_ip
    end
  end

end

