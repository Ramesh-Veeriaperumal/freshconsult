module Cache::Memcache::SubscriptionPlan
  include MemcacheKeys

  def self.included(base)
    base.extend ClassMethods
  end

  def retrieve_plan_from_cache(plan, renewal_period)
    key = plan.chargebee_plan_cache_key(renewal_period,
      Account.current.subscription.currency_name)
    fetch_from_cache(key) { Billing::Subscription.new.retrieve_plan(plan.name, renewal_period) }
  end

  def clear_cache
    Subscription::Currency.all.collect(&:name).each do |currency|
      Billing::Subscription::BILLING_PERIOD.keys.each do |period|
        delete_value_from_cache(chargebee_plan_cache_key(period, currency))
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
      omni_account = Account.current.omni_bundle_account? if Account.current.present?
      MemcacheKeys.fetch(MemcacheKeys::SUBSCRIPTION_PLANS) do 
        SubscriptionPlan.select("id,name,display_name,classic").all
      end.select { |plan| omni_account ? (!plan.classic && plan.omni_plan?) : plan.classic == false }
    end

    def current_plan_names_from_cache
      cached_current_plans.map(&:name)
    end

    def subscription_plans_from_cache
      MemcacheKeys.fetch(MemcacheKeys::SUBSCRIPTION_PLANS) do
        SubscriptionPlan.select('id,name,display_name,classic').all
      end
    end
  end
end
