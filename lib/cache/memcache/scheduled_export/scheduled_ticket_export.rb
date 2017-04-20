module Cache::Memcache::ScheduledExport::ScheduledTicketExport

  include MemcacheKeys

  def clear_scheduled_exports_account_cache
    key = ACCOUNT_SCHEDULED_TICKET_EXPORTS % { :account_id => self.account_id }
    MemcacheKeys.delete_from_cache key
  end

end