module Cache::Memcache::SubscriptionPlan
  include MemcacheKeys

  def self.included(base)
    base.extend ClassMethods
  end

  def subscription_plans_from_cache
    @subscription_plans_from_cache ||= MemcacheKeys.fetch(SUBSCRIPTION_PLANS) do
      SubscriptionPlan.select("id,name,display_name,classic").all
    end
  end

  def clear_cache
    Subscription::Currency.all.collect(&:name).each do |currency|
      Billing::Subscription::BILLING_PERIOD.keys.each do |period|
        MemcacheKeys.delete_from_cache(chargebee_plan_cache_key(period, currency))
      end
    end
    MemcacheKeys.delete_multiple_from_cache [SUBSCRIPTION_PLANS, 
      PLANS_AGENT_COSTS_BY_CURRENCY]
  end

  def chargebee_plan_cache_key(renewal_period, currency)
    format(MemcacheKeys::CHARGEBEE_SUBSCRIPTION_PLAN, plan_name: self.canon_name.to_s,
      period: renewal_period, currency: currency)
  end

  module ClassMethods
    
    def cached_current_plans
      MemcacheKeys.fetch(MemcacheKeys::SUBSCRIPTION_PLANS) do 
        SubscriptionPlan.select("id,name,display_name,classic").all
      end.select { |plan| plan.classic == false }
    end

    def current_plan_names_from_cache
      cached_current_plans.map(&:name)
    end
  end
end
