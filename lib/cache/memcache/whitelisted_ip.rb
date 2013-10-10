module Cache::Memcache::WhitelistedIp
	
	include MemcacheKeys

	def clear_whitelisted_ip_cache
		key = WHITELISTED_IP_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
	end

end