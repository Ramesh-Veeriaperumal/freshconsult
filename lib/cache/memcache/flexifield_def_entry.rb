module Cache::Memcache::FlexifieldDefEntry

	include MemcacheKeys

	def clear_cache
    if flexifield_def.module == 'Ticket'
  		key = ACCOUNT_EVENT_FIELDS % { :account_id => self.account_id }
  		MemcacheKeys.delete_from_cache key
  		key = ACCOUNT_FLEXIFIELDS % { :account_id => self.account_id }
  		MemcacheKeys.delete_from_cache key
    end
	end
  

end