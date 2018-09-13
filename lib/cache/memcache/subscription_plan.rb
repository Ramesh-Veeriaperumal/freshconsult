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
    MemcacheKeys.delete_multiple_from_cache [SUBSCRIPTION_PLANS, 
      PLANS_AGENT_COSTS_BY_CURRENCY]
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
