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
		key = ACCOUNT_TICKET_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
		key = ACCOUNT_NESTED_TICKET_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
		key = ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING % { account_id: self.account_id }
		MemcacheKeys.delete_from_cache key
		key = ACCOUNT_REQUIRED_TICKET_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache(key) if product_field_set_reqd_false
		key = ACCOUNT_SECTION_PARENT_FIELDS % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache(key) if product_field_set_reqd_false
		key = ACCOUNT_TICKET_TYPES % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache(key)
		key = TICKET_FIELDS_FULL % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache(key)
		# In Scripts, clear_all_section_ticket_fields_cache in Cache::Memcache::Helpdesk::Section
	end

	def product_field_set_reqd_false
		self.field_type == "default_product" && self.previous_changes.has_key?(:required_for_closure) && !self.required_for_closure?
	end
  
end
