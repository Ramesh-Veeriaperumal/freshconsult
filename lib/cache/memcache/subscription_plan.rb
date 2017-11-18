module Cache::Memcache::SubscriptionPlan
  include MemcacheKeys

  def subscription_plans_from_cache
    @subscription_plans_from_cache ||= MemcacheKeys.fetch(SUBSCRIPTION_PLANS) { SubscriptionPlan.select("id,name,display_name").all }
  end

  def clear_cache
  	MemcacheKeys.delete_from_cache(SUBSCRIPTION_PLANS)
  end
end
