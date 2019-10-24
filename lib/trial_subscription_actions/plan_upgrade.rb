class TrialSubscriptionActions::PlanUpgrade < TrialSubscriptionActions::Base
  include Redis::RateLimitRedis

  def execute
    if !get_account_api_limit || get_redis_api_expiry(account_api_limit_key) > 0
      set_account_api_limit_with_expiry
    end
    super
  end

  private

    def plan_features
      @plan_features ||= (::PLANS[:subscription_plans][SubscriptionPlan::SUBSCRIPTION_PLANS.key(trial_plan)][:features].dup - (UnsupportedFeaturesList || []))
    end

    def dashboard_plan?
      DASHBOARD_PLANS.include?(trial_plan)
    end

    def features_list_to_add_data
      ADD_DATA_FEATURES
    end

    def handle_feature_drop_data
      # No features data are required to remove in trial upgrade
    end

    def account_api_limit_key
      ACCOUNT_API_LIMIT % { account_id: Account.current.id }
    end

    def set_account_api_limit_with_expiry
      trial_plan = find_plan_by_name(@trial_subscription.trial_plan)
      if trial_plan.present?
        plan_key = format(PLAN_API_LIMIT, plan_id: trial_plan.id)
        set_account_api_limit(get_api_rate_limit(plan_key))
        set_redis_expiry(account_api_limit_key, @trial_subscription.ends_at.to_i - Time.now.to_i)
      end
    end

    def find_plan_by_name(plan_name)
      SubscriptionPlan.cached_current_plans.find { |plan| plan.name == plan_name }
    end
end
