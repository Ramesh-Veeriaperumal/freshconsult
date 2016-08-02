module Cache::Memcache::Helpdesk::Ticket

  include MemcacheKeys

  def agent_new_tkt_form_memcache_key
    set_redis_lang_list(fragment_cache_redis_key(Redis::RedisKeys::AGENT_LANGUAGE_LIST), "#{I18n.locale}")
    memcache_key(AGENT_NEW_TICKET_FORM)
  end

  def agent_compose_email_memcache_key
    set_redis_lang_list(fragment_cache_redis_key(Redis::RedisKeys::AGENT_LANGUAGE_LIST), "#{I18n.locale}")
    memcache_key(COMPOSE_EMAIL_FORM)
  end

  def clear_tkt_form_cache
    redis_key = fragment_cache_redis_key(Redis::RedisKeys::AGENT_LANGUAGE_LIST)
    lang      = get_redis_lang_list(redis_key)
    [AGENT_NEW_TICKET_FORM, COMPOSE_EMAIL_FORM].each do |k|
      lang.each do |l|
        key = memcache_key(k,l)
        ActionController::Base.new.expire_fragment(key)
      end
    end
    clear_redis_lang_list(redis_key)
  end

  private
  
  def set_redis_lang_list(key, value)
    add_member_to_redis_set(key, value)
  end

  def get_redis_lang_list(key)
    get_all_members_in_a_redis_set(key)
  end

  def clear_redis_lang_list(key)
    remove_others_redis_key(key)
  end

  def fragment_cache_redis_key(redis_key, account = Account.current)
    redis_key % {:account_id => account.id}
  end

  def memcache_key key, language = I18n.locale, account=Account.current
    key % {:account_id => account.id, :language => "#{language}"}
  end
end