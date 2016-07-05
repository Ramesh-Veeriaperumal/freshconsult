module Cache::Memcache::AccountWebhookKeyCache
  
  include MemcacheKeys

  def account_webhook_key_from_cache(service_id)
    key = ACCOUNT_WEBHOOK_KEY % {:account_id => Account.current.id, :vendor_id => service_id}
    MemcacheKeys.fetch(key) { AccountWebhookKey.find_by_account_id(Account.current.id).webhook_key }
  end

  def clear_account_webhook_key_cache
    key = ACCOUNT_WEBHOOK_KEY % {:account_id => self.account_id, :vendor_id => self.service_id}
    MemcacheKeys.delete_from_cache key
  end
  
end