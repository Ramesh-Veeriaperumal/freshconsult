module Cache::Memcache::FlexifieldDefEntry
  include MemcacheKeys

  def clear_flexifield_def_entry_cache
    if flexifield_def.module == 'Ticket'
      key = format(ACCOUNT_EVENT_FIELDS, account_id: self.account_id)
      delete_value_from_cache key
      key = format(ACCOUNT_FLEXIFIELDS, account_id: self.account_id)
      delete_value_from_cache key
    end
  end

  def clear_cache
    key = format(ACCOUNT_EVENT_FIELDS, account_id: self.account_id)
    delete_value_from_cache key
    key = format(ACCOUNT_FLEXIFIELDS, account_id: self.account_id)
    delete_value_from_cache key
  end
end
