module Redis::RoutesRedis

	def set_route_info(portal_url, account_id, full_domain)
		# Namespace route is used to differentiate routing keys.
		newrelic_begin_rescue { $redis_routes.hmset(
													"route:#{portal_url}", 
													"account_id", account_id, 
													"full_domain", full_domain, 
													"pod", PodConfig['CURRENT_POD']
													) }
	end

	def delete_route_info portal_url
		newrelic_begin_rescue { $redis_routes.del("route:#{portal_url}") }
	end
end