# AR-Shards is not thread-safe
# we need to preload connections for threaded environments 
# to avoid race-conditions during accessing/setting connection pools
if ENV["THREADED_APP"]
	Sharding.run_on_all_shards {
		Sharding.run_on_slave {
		}
	}
end