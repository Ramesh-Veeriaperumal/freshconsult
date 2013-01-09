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
    statuses = MemcacheKeys.fetch(key) { account.ticket_status_values.find(:all) }
    disp_col_name = self.display_name
    statuses.map{|status| [status.status_id, translate_status_name(status, disp_col_name)]}
  end

  def statuses_from_cache(account)
    disp_col_name = self.display_name
    key = statuses_memcache_key(account.id)
    statuses = MemcacheKeys.fetch(key) { account.ticket_status_values.find(:all) }
    statuses.map{|status| [translate_status_name(status, disp_col_name), status.status_id]}  
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