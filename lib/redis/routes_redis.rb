module Redis::RoutesRedis
	# TODO: After enabling signup in all PODs remove POD_REDIRECTION_LOCAL_CACHE_KEY
	# & POD_REDIRECTION_LOCAL_CACHE_EXPIRY constants.
	POD_REDIRECTION_LOCAL_CACHE_KEY = "LC:#{Redis::Keys::Routes::POD_REDIRECTION}".freeze
	POD_REDIRECTION_LOCAL_CACHE_EXPIRY = 1.minute

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

	# TODO: After enabling signup in all PODs remove pod_redirection_enabled?() and its reated code.
	def self.pod_redirection_enabled?
		Rails.cache.fetch(POD_REDIRECTION_LOCAL_CACHE_KEY, expires_in: POD_REDIRECTION_LOCAL_CACHE_EXPIRY) do
			value = $redis_routes.perform_redis_op('exists', Redis::Keys::Routes::POD_REDIRECTION)
      Rails.logger.debug("POD redirection key exists?, #{value}")
      value
    end
	end
end