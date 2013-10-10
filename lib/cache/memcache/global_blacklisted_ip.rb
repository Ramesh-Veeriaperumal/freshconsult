module Cache::Memcache::GlobalBlacklistedIp
	
	include MemcacheKeys

	def blacklisted_ips
		key = GLOBAL_BLACKLISTED_IPS
		MemcacheKeys.fetch(key) { GlobalBlacklistedIp.first }
	end

	def clear_blacklisted_ip_cache
		key = GLOBAL_BLACKLISTED_IPS
		MemcacheKeys.delete_from_cache key
	end

end