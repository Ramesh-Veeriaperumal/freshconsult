class Middleware::GlobalRestriction

  include Cache::Memcache::GlobalBlacklistIp

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = blacklisted_ips.ip_list
    req = Rack::Request.new(env)
    env['CLIENT_IP'] = req.ip()
    if ip && ip.include?(env['CLIENT_IP'])
  		@status, @headers, @response = [302, {"Location" => "/unauthorized.html"}, 
                                      ['Your IPAddress is blocked by the administrator']]
      return [@status, @headers, @response]
    end
  	@status, @headers, @response = @app.call(env)
  end

end