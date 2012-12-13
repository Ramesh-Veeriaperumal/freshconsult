module Cache::Memcache::Helpdesk::TicketField
	
	include MemcacheKeys

	PICKLIST_KEYS = { "default_ticket_type" => ACCOUNT_TICKET_TYPES }

	def clear_picklist_cache
		memcache_key = PICKLIST_KEYS[self.field_type]
		MemcacheKeys.delete_from_cache(memcache_key % { :account_id => self.account_id })  if memcache_key
	end

	def clear_cache
		key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
		key = ACCOUNT_NESTED_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
	end
  
end