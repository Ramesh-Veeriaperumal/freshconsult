module Cache::Memcache::VARule

	include MemcacheKeys

	def clear_observer_rules_cache
		key = ACCOUNT_OBSERVER_RULES % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
	end
  
  def clear_api_webhook_rules_from_cache
  	key = ACCOUNT_API_WEBHOOKS_RULES % { :account_id => self.account_id }
		MemcacheKeys.delete_from_cache key
  end

  def clear_installed_app_business_rules_from_cache
    key = ACCOUNT_INSTALLED_APP_BUSINESS_RULES % { :account_id => self.account_id }
    MemcacheKeys.delete_from_cache key
  end

  def clear_cache
    clear_observer_rules_cache
    clear_api_webhook_rules_from_cache
    clear_installed_app_business_rules_from_cache
  end
end
