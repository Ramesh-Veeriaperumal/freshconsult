module Cache::Memcache::User
	
	include MemcacheKeys

	def clear_agent_list_cache
		MemcacheKeys.delete_from_cache(ACCOUNT_AGENTS % { :account_id => self.account_id })
	end

end
