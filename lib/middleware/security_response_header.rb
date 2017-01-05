class Middleware::SecurityResponseHeader
 def initialize(app)
   @app = app
 end

 def call(env)
   req_path = env['PATH_INFO']
   status, headers, response    = @app.call(env)
   headers["X-XSS-Protection"] = "1; mode=block"
   #headers["X-Content-Type-Options"]  = "nosniff"
   headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
   if req_path.include? 'login'
        headers["Content-Security-Policy"] = "frame-ancestors 'none'"
   end
  [status, headers, response]
 end
end
