class Middleware::GlobalRestriction

  include Cache::Memcache::GlobalBlacklistIp

  def initialize(app)
    @app = app
  end

  def call(env)
    ip = blacklisted_ips.ip_list
    req = Rack::Request.new(env)
    req_path = req.path_info
    env['CLIENT_IP'] = req.ip()
    if ip && ip.include?(env['CLIENT_IP'])
  		@status, @headers, @response = set_response(req_path)
      return [@status, @headers, @response]
    end
  	@status, @headers, @response = @app.call(env)
  end

  def set_response(req_path)
    if req_path.starts_with?('/api/')
      return [403, {"Content-type" => "application/json"}, [{message: "Your IPAddress is blocked by the administrator"}.to_json]]
    else
      return [302, {"Location" => "/unauthorized.html"}, ['Your IPAddress is blocked by the administrator']]
    end
  end

end