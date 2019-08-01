include Redis::RedisWrapper

config = YAML::load_file(File.join(Rails.root, 'config', 'redis.yml'))[Rails.env]
routes_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_routes.yml'))[Rails.env]
rate_limit = YAML.load_file(File.join(Rails.root, 'config', 'rate_limit.yml'))[Rails.env]
display_id_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_display_id.yml'))[Rails.env]
round_robin_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_round_robin.yml'))[Rails.env]
redis_session_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_session.yml'))[Rails.env]
mobile_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_mobile.yml'))[Rails.env]
automation_rule_config = YAML::load_file(File.join(Rails.root, 'config', 'automation_rule_redis.yml'))[Rails.env]
#$redis = Redis.new(:host => config["host"], :port => config["port"])

#$redis_secondary = Redis.new(:host => config["host"], :port => config["port"])

#For logging redis performance timings
TimeBandits.add ::TimeBandits::TimeConsumers::Redis
ENV["TIME_BANDITS_VERBOSE"] = "true" if Rails.env.development? #logging is enabled and default for development env

$redis_tickets = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_reports = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_integrations = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_portal = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_others = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$spam_watcher = Redis.new(:host => rate_limit["host"], :port => rate_limit["port"], :timeout => rate_limit["timeout"], :tcp_keepalive => rate_limit["keepalive"])
$rate_limit = Redis.new(:host => rate_limit["host"], :port => rate_limit["port"], :timeout => rate_limit["timeout"], :tcp_keepalive => rate_limit["keepalive"]) # Used by fd_api_throttler.
$redis_routes = Redis.new(:host => routes_config["host"], :port => routes_config["port"], :timeout => routes_config["timeout"], :tcp_keepalive => routes_config["keepalive"])
$redis_display_id = Redis.new(:host => display_id_config["host"], :port => display_id_config["port"], :timeout => display_id_config["timeout"], :tcp_keepalive => display_id_config["keepalive"])
$redis_mkp = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_round_robin = Redis.new(:host => round_robin_config["host"], :port => round_robin_config["port"], :timeout => round_robin_config["timeout"], :tcp_keepalive => round_robin_config["keepalive"])
$redis_session = Redis.new(:host => redis_session_config["host"], :port => redis_session_config["port"],:timeout => redis_session_config["timeout"], :tcp_keepalive => redis_session_config["keepalive"])
$redis_mobile = Redis.new(:host => mobile_config["host"], :port => mobile_config["port"], :timeout => mobile_config["timeout"], :tcp_keepalive => mobile_config["keepalive"])
$semaphore = Redis.new(:host => config["host"], :port => config["port"], :timeout => config["timeout"], :tcp_keepalive => config["keepalive"])
$redis_automation_rule = Redis.new(host:  automation_rule_config['host'], port: automation_rule_config['port'], timeout: automation_rule_config["timeout"], tcp_keepalive: automation_rule_config["keepalive"])
# Include connection objects to new redis instances here. This is used for redis_maintenance.rake.
# There are 3 DBs per region, having one connection object per DB below.
REDIS_UNIQUE_CONNECTION_OBJECTS = [$redis_tickets, $rate_limit]

#Loading Redis Display Id's Lua script
Redis::DisplayIdLua.load_display_id_lua_script_to_redis
Redis::DisplayIdLua.load_picklist_id_lua_script

Redis.class_eval {add_method_tracer :set}
Redis.class_eval {add_method_tracer :get}
Redis.class_eval {add_method_tracer :del}
Redis.class_eval {add_method_tracer :sadd}
Redis.class_eval {add_method_tracer :srem}
Redis.class_eval {add_method_tracer :smembers}
Redis.class_eval {add_method_tracer :sismember}
Redis.class_eval {add_method_tracer :rpush}
Redis.class_eval {add_method_tracer :lpush}
Redis.class_eval {add_method_tracer :lrange}
Redis.class_eval {add_method_tracer :llen}
Redis.class_eval {add_method_tracer :keys}
Redis.class_eval {add_method_tracer :hset}
Redis.class_eval {add_method_tracer :hget}
Redis.class_eval {add_method_tracer :hmset}
Redis.class_eval {add_method_tracer :hmget}
Redis.class_eval {add_method_tracer :exists}
Redis.class_eval {add_method_tracer :ttl}
Redis.class_eval {add_method_tracer :lpop}
Redis.class_eval {add_method_tracer :lrem}
Redis::Client.class_eval {add_method_tracer :read}
Redis::Client.class_eval {add_method_tracer :process}
Redis::Client.class_eval {add_method_tracer :connect}
LaunchParty.configure(:redis => Redis::Namespace.new(:launchparty, :redis => $redis_others))
