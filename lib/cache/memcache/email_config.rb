module  Cache::Memcache::EmailConfig
  include MemcacheKeys

  def clear_cache mailbox
    MemcacheKeys.delete_from_cache(format(OAUTH_MAILBOX_STATUS_CHECK, account_id: Account.current.id))
  end

end