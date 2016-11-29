
require 'rack/request'

class Middleware::SecurityResponseHeader
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    resource = env['PATH_INFO']
    status, headers, body      = @app.call(request.env)
     headers["X-XSS-Protection"] = "1; mode=block"
     headers["X-Content-Type-Options"]  = "nosniff"
     headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    if resource.include? 'login'
       headers["Content-Security-Policy"] = "frame-ancestors 'none'"
    end
    [status, headers, body]
  end
end
