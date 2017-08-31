class Middleware::LogRedisCalls
  include Redis::RedisTracker

  def initialize(app)
    @app = app
  end

  def call(env)
    req_path = env['PATH_INFO']
    init_redis_tracker
    status, headers, response = @app.call(env)
    log_redis_stats(req_path)
    [status, headers, response]
  end
end
