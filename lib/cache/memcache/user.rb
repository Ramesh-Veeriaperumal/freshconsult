module Cache::Memcache::User
	
	include MemcacheKeys

	def clear_agent_list_cache
		delete_value_from_cache(ACCOUNT_AGENTS % { :account_id => self.account_id })
		delete_value_from_cache(ACCOUNT_AGENTS_DETAILS % { :account_id => self.account_id })
	end

	def clear_agent_name_cache
		delete_value_from_cache(ACCOUNT_AGENT_NAMES % { :account_id => self.account_id })
	end

	def clear_cache
		clear_agent_list_cache
		clear_agent_name_cache
	end
end
