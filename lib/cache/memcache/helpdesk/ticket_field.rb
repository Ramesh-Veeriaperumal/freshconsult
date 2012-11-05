module Cache::Memcache::Helpdesk::TicketField
	
	include MemcacheKeys

	PICKLIST_KEYS = { "default_ticket_type" => ACCOUNT_TICKET_TYPES }

	def clear_picklist_cache
		memcache_key = PICKLIST_KEYS[self.field_type]
		MemcacheKeys.delete_from_cache(memcache_key % { :account_id => self.account_id })  if memcache_key
	end
  
end