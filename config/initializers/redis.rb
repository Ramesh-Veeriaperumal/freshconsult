
config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redis.yml'))[RAILS_ENV]

$redis = Redis.new(:host => config["host"], :port => config["port"])

$redis_secondary = Redis.new(:host => config["host"], :port => config["port"])

Redis.class_eval {add_method_tracer :set}
Redis.class_eval {add_method_tracer :get}
Redis.class_eval {add_method_tracer :sadd}
Redis.class_eval {add_method_tracer :lpop}
Redis.class_eval {add_method_tracer :rpush}
Redis::Connection.class_eval {add_method_tracer :read}
Redis::Connection.class_eval {add_method_tracer :write}
Redis::Connection.class_eval {add_method_tracer :connect}