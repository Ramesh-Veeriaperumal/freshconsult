module Cache::Memcache::AccountWebhookKeyCache
  
  include MemcacheKeys

  def account_webhook_key_from_cache(vendor_id)
    key = ACCOUNT_WEBHOOK_KEY % {:account_id => Account.current.id, :vendor_id => vendor_id}
    MemcacheKeys.fetch(key) { AccountWebhookKey.find_by_account_id_and_vendor_id(Account.current.id, vendor_id) }
  end

  def clear_account_webhook_key_cache
    key = ACCOUNT_WEBHOOK_KEY % {:account_id => self.account_id, :vendor_id => self.vendor_id}
    MemcacheKeys.delete_from_cache key
  end
  
end