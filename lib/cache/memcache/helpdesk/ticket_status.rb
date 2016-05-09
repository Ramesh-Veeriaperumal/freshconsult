module Cache::Memcache::Helpdesk::TicketStatus

  include MemcacheKeys

  def clear_statuses_cache
    key = statuses_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
    key = onhold_and_closed_memcache_key(Account.current.id)
    MemcacheKeys.delete_from_cache(key)
  end

  def status_names_from_cache(account)
    disp_col_name = self.display_name
    statuses = status_objects_from_cache(account)
    statuses.map{|status| [status.status_id, translate_status_name(status, disp_col_name)]}
  end

  def statuses_from_cache(account)
    disp_col_name = self.display_name
    statuses = status_objects_from_cache(account)
    statuses.map{|status| [translate_status_name(status, disp_col_name), status.status_id]}  
  end

  def status_objects_from_cache(account)
    account.ticket_status_values_from_cache
  end
  
  private
    def onhold_and_closed_memcache_key(account_id)
      ACCOUNT_ONHOLD_CLOSED_STATUSES % { :account_id => account_id }
    end

    def statuses_memcache_key(account_id)
      ACCOUNT_STATUSES % { :account_id => account_id }
    end


end