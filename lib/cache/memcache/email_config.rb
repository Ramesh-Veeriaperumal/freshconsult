module  Cache::Memcache::EmailConfig
  include MemcacheKeys

  def clear_cache mailbox
    MemcacheKeys.delete_from_cache(CUSTOM_MAILBOX_STATUS_CHECK % { :account_id => mailbox.account_id })
  end

end