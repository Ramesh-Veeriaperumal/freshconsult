module Cache::Memcache::Helpdesk::TicketStatus

  include MemcacheKeys

  def clear_statuses_cache
    key = status_names_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_onhold_closed_statuses_cache
    key = onhold_and_closed_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
  end

  def onhold_and_closed_statuses_from_cache(account)
    key = onhold_and_closed_memcache_key(account.id)
    MemcacheKeys.fetch(key) { onhold_and_closed_statuses(account) }
  end

  def status_names_from_cache(account)
    key = status_names_memcache_key(account.id)
    MemcacheKeys.fetch(key) { self.status_names(account) }
  end
  
  private
    def onhold_and_closed_memcache_key(account_id)
      ACCOUNT_ONHOLD_CLOSED_STATUSES % { :account_id => account_id }
    end

    def status_names_memcache_key(account_id)
      ACCOUNT_STATUSES % { :account_id => account_id }
    end


end