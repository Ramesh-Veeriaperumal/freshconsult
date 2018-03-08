module Cache::Memcache::Helpdesk::TicketTemplate

  include MemcacheKeys

  def  prime_templates_count_from_cache
    MemcacheKeys.fetch(template_key) { Account.current.prime_templates.count }
  end

  def clear_template_count_cache
    MemcacheKeys.delete_from_cache template_key
  end

  def template_key
    key = PRIME_TKT_TEMPLATES_COUNT % {:account_id => Account.current.id}
  end

  def clear_cache
    clear_template_count_cache
  end
end