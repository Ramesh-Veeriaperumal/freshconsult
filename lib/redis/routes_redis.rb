module Redis::RoutesRedis


	def self.set_route_info(portal_url, account_id, full_domain)
		# Namespace route is used to differentiate routing keys.
		MemcacheKeys.newrelic_begin_rescue { $redis_routes.perform_redis_op(
													"hmset", "route:#{portal_url}", 
													"account_id", account_id, 
													"full_domain", full_domain, 
													"pod", PodConfig['CURRENT_POD']
													) }
	end

	def self.update_pod_info(portal_url, pod_info)
		MemcacheKeys.newrelic_begin_rescue { $redis_routes.perform_redis_op(
													"hmset", "route:#{portal_url}", 
													"pod", pod_info
													) }
	end

	def self.delete_route_info portal_url
		MemcacheKeys.newrelic_begin_rescue { $redis_routes.perform_redis_op("del", "route:#{portal_url}") }
	end

end