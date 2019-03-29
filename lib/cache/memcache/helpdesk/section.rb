module Cache::Memcache::Helpdesk::Section

  include MemcacheKeys

  def reqd_ticket_fields
    @reqd_ticket_fields ||= begin
      if Account.current.caching_enabled?
        key = required_ticket_fields_key
        MemcacheKeys.fetch(key) { self.required_ticket_fields.all }
      else
        self.required_ticket_fields.all
      end
    end
  end

  def clear_cache
    key = format(ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING, account_id: account_id)
    MemcacheKeys.delete_from_cache key
    key = format(ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, account_id: account_id)
    MemcacheKeys.delete_from_cache key
  end

  def required_ticket_fields_key
    SECTION_REQUIRED_TICKET_FIELDS % { :account_id => self.account_id, :section_id => self.id }
  end

  def clear_all_section_ticket_fields_cache
    account = Account.current
    account.sections.find_each do |section|
      key = section.required_ticket_fields_key
      MemcacheKeys.delete_from_cache key
    end
  end
end
