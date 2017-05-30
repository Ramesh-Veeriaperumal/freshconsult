class Middleware::SecurityResponseHeader

  include Redis::RedisKeys
  include Redis::OthersRedis

 def initialize(app)
   @app = app
 end

 def call(env)
  request = Rack::Request.new(env)
  req_path = env['PATH_INFO']
  status, headers, response    = @app.call(env)
  headers["X-XSS-Protection"] = "1; mode=block"
  #headers["X-Content-Type-Options"]  = "nosniff"
  if redis_key_exists?(IFRAME_WHITELIST_DOMAIN)
    unless ismember?(IFRAME_WHITELIST_DOMAIN, req_path)
      headers["Content-Security-Policy"] = "frame-ancestors 'none'"
    end
  end

  # TODO: need to remove this check when all iframes are removed in Falcon
  # for Falcon UI iframe compatibility
  falcon_iframe_pages = [
    '/admin/home',
    '/social/welcome',
    '/discussions/',
    '/discussions/categories',
    '/discussions/forums/',
    '/discussions/topics/',
    '/forums',
    '/reports',
    '/solution/articles/',
    '/solution/categories/',
    '/solution/folders/'
  ]
  if falcon_iframe_pages.include? req_path
    headers["Content-Security-Policy"] = "frame-ancestors 'self'"
  end

  [status, headers, response]
 end
end
