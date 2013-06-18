module Cache::Memcache::VARule

	include MemcacheKeys

	def clear_observer_rules_cache
		key = ACCOUNT_OBSERVER_RULES % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
	end
  
end