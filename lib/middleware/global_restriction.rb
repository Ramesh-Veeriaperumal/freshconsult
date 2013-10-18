class Middleware::GlobalRestriction

  include Cache::Memcache::GlobalBlacklistIp

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = blacklisted_ips.ip_list
    request_ip = env['REMOTE_ADDR']
    if ip && ip.include?(request_ip)
  		@status, @headers, @response = [302, {"Location" => "/unauthorized.html"}, 
                                      'Your IPAddress is bocked by the administrator']
      return [@status, @headers, @response]
    end
  	@status, @headers, @response = @app.call(env)
  end

end