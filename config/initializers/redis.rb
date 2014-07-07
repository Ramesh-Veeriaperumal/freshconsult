config = YAML::load_file(File.join(Rails.root, 'config', 'redis.yml'))[Rails.env]

#$redis = Redis.new(:host => config["host"], :port => config["port"])

#$redis_secondary = Redis.new(:host => config["host"], :port => config["port"])

$redis_tickets = Redis.new(:host => config["host"], :port => config["port"])
$redis_reports = Redis.new(:host => config["host"], :port => config["port"])
$redis_integrations = Redis.new(:host => config["host"], :port => config["port"])
$redis_portal = Redis.new(:host => config["host"], :port => config["port"])
$redis_others = Redis.new(:host => config["host"], :port => config["port"])

mobile_config = YAML::load_file(File.join(Rails.root, 'config', 'redis_mobile.yml'))[Rails.env]
$redis_mobile = Redis.new(:host => mobile_config["host"], :port => mobile_config["port"])

Redis.class_eval {add_method_tracer :set}
Redis.class_eval {add_method_tracer :get}
Redis.class_eval {add_method_tracer :del}
Redis.class_eval {add_method_tracer :sadd}
Redis.class_eval {add_method_tracer :srem}
Redis.class_eval {add_method_tracer :smembers}
Redis.class_eval {add_method_tracer :rpush}
Redis.class_eval {add_method_tracer :lpush}
Redis.class_eval {add_method_tracer :lrange}
Redis.class_eval {add_method_tracer :llen}
Redis.class_eval {add_method_tracer :keys}
Redis.class_eval {add_method_tracer :hset}
Redis.class_eval {add_method_tracer :hget}
Redis.class_eval {add_method_tracer :exists}
Redis.class_eval {add_method_tracer :ttl}
Redis.class_eval {add_method_tracer :lpop}
Redis.class_eval {add_method_tracer :lrem}
Redis::Client.class_eval {add_method_tracer :read}
Redis::Client.class_eval {add_method_tracer :process}
Redis::Client.class_eval {add_method_tracer :connect}
