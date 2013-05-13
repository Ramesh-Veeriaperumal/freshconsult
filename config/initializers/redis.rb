
config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redis.yml'))[RAILS_ENV]

$redis = Redis.new(:host => config["host"], :port => config["port"])

$redis_secondary = Redis.new(:host => config["host"], :port => config["port"])