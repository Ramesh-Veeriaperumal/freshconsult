FdRateLimiter.configure do |config|
  config.global_enable = true
  config.redis_cli = $spam_watcher
  config.redis_timeout = 0.1
  config.lua_sha = 'f25cbd48715428d92f46985cd8cfd503571c3af4'
end

module ResourceRateLimit
	NOTIFY_KEYS = 'resource_rate_limit_queue'
end