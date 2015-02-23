config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redis.yml'))[RAILS_ENV]
routes_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_routes.yml'))[Rails.env]
rate_limit = YAML.load_file(File.join(RAILS_ROOT, 'config', 'rate_limit.yml'))[RAILS_ENV]
display_id_config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redis_display_id.yml'))[RAILS_ENV]
#$redis = Redis.new(:host => config["host"], :port => config["port"])

#$redis_secondary = Redis.new(:host => config["host"], :port => config["port"])

$redis_tickets = Redis.new(:host => config["host"], :port => config["port"])
$redis_reports = Redis.new(:host => config["host"], :port => config["port"])
$redis_integrations = Redis.new(:host => config["host"], :port => config["port"])
$redis_portal = Redis.new(:host => config["host"], :port => config["port"])
$redis_others = Redis.new(:host => config["host"], :port => config["port"])
$spam_watcher = Redis.new(:host => rate_limit["host"], :port => rate_limit["port"])
$redis_routes = Redis.new(:host => routes_config["host"], :port => routes_config["port"])
$redis_display_id = Redis.new(:host => display_id_config["host"], :port => display_id_config["port"])

mobile_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_mobile.yml'))[Rails.env]
$redis_mobile = Redis.new(:host => mobile_config["host"], :port => mobile_config["port"])

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
