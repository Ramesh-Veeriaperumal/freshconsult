module Cache::Memcache::Helpdesk::Ticket

  include MemcacheKeys

  def agent_new_tkt_form_memcache_key
    memcache_key(AGENT_NEW_TICKET_FORM)
  end

  def agent_compose_email_memcache_key
    memcache_key(COMPOSE_EMAIL_FORM)
  end

  def clear_tkt_form_cache
    [AGENT_NEW_TICKET_FORM, COMPOSE_EMAIL_FORM].each do |k|
      key = memcache_key(k)
      ActionController::Base.new.expire_fragment(key)
    end
  end

  def memcache_key key, account=Account.current
    key % {:account_id => account.id}
  end
end