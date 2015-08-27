$redis_features = Redis.new(:host => config["host"], :port => config["port"])
$rollout = Rollout.new($redis_features)