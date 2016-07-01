module Cache::Memcache::Helpdesk::TicketTemplate

  include MemcacheKeys

  def templates_count_from_cache
    MemcacheKeys.fetch(template_key) { Account.current.ticket_templates.count }
  end

  def clear_template_count_cache
    MemcacheKeys.delete_from_cache template_key
  end

  def template_key
    key = TKT_TEMPLATES_COUNT % {:account_id => Account.current.id}
  end
end