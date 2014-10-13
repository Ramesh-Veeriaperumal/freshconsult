module Cache::Memcache::Helpdesk::Tag

	include MemcacheKeys

	def clear_cache
		MemcacheKeys.delete_from_cache(ACCOUNT_TAGS % { :account_id =>self.account_id })
	end
  
end