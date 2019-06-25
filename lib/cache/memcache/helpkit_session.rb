module Cache::Memcache::HelpkitSession

  include MemcacheKeys

  def clear_session_cache
    key = SESSION_BY_ID % { :session_id => session_id }
    MemcacheKeys.delete_from_cache key
  end
end