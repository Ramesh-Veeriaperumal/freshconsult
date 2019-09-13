module Cache::Memcache::Helpdesk::Tag
  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(format(ACCOUNT_TAGS, account_id: account_id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_TAGS_OPTAR, account_id: account_id))
  end
end
