module Cache::Memcache::Helpdesk::TicketStatus

  include MemcacheKeys

  def clear_statuses_cache
    key = statuses_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
    key = status_names_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
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

  def statuses_from_cache(account)
    key = statuses_memcache_key(account.id)
    MemcacheKeys.fetch(key) { self.statuses(account) }
  end

  
  private
    def onhold_and_closed_memcache_key(account_id)
      ACCOUNT_ONHOLD_CLOSED_STATUSES % { :account_id => account_id }
    end

    def status_names_memcache_key(account_id)
      ACCOUNT_STATUS_NAMES % { :account_id => account_id }
    end

    def statuses_memcache_key(account_id)
      ACCOUNT_STATUSES % { :account_id => account_id }
    end


end