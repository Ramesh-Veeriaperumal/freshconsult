include Redis::ClientPatch if ENV['PATCH_REDIS_CLIENT']
include Redis::RedisWrapper

def load_file(config_path)
  YAML.load_file(Rails.root.join('config', config_path))[Rails.env]
end

config = load_file('redis.yml')
routes_config = load_file('redis_routes.yml')
rate_limit = load_file('rate_limit.yml')
display_id_config = load_file('redis_display_id.yml')
round_robin_config = load_file('redis_round_robin.yml')
redis_session_config = load_file('redis_session.yml')
mobile_config = load_file('redis_mobile.yml')
automation_rule_config = load_file('automation_rule_redis.yml')

# For logging redis performance timings
TimeBandits.add ::TimeBandits::TimeConsumers::Redis
ENV['TIME_BANDITS_VERBOSE'] = 'true' if Rails.env.development? # logging is enabled and default for development env

# Include connection objects to new redis instances here. This is used for redis_maintenance.rake.
# There are 3 DBs per region, having one connection object per DB below.
REDIS_CONFIG_KEYS = ['host', 'port', 'timeout', 'connect_timeout',
                     'password', 'retry_password', 'retry_port', 'retry_host'].freeze

def fetch_options(options)
  redis_options = options.slice(*REDIS_CONFIG_KEYS).merge(tcp_keepalive: options['keepalive'])
  HashWithIndifferentAccess.new(redis_options)
end

$redis_tickets = Redis.new(fetch_options(config))
$redis_reports = Redis.new(fetch_options(config))
$redis_integrations = Redis.new(fetch_options(config))
$redis_portal = Redis.new(fetch_options(config))
$redis_others = Redis.new(fetch_options(config))
$spam_watcher = Redis.new(fetch_options(rate_limit))
$rate_limit = Redis.new(fetch_options(rate_limit)) # Used by fd_api_throttler.
$redis_routes = Redis.new(fetch_options(routes_config))
$redis_display_id = Redis.new(fetch_options(display_id_config))
$redis_mkp = Redis.new(fetch_options(config))
$redis_round_robin = Redis.new(fetch_options(round_robin_config))
$redis_session = Redis.new(fetch_options(redis_session_config))
$redis_mobile = Redis.new(fetch_options(mobile_config))
$semaphore = Redis.new(fetch_options(config))
$redlock = Redis.new(fetch_options(config))
$redis_automation_rule = Redis.new(fetch_options(automation_rule_config))

REDIS_UNIQUE_CONNECTION_OBJECTS = [$redis_tickets, $rate_limit].freeze

Redis::DisplayIdLua.load_display_id_lua_script_to_redis
Redis::DisplayIdLua.load_picklist_id_lua_script
Redis::DisplayIdLua.load_ticket_source_choice_id_lua_script

Redis::ResyncRatelimitterLua.load_resync_ratelimitter_lua_script

Redis::Redlock.load_unlock_lua_script_to_redis

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
