class TrialSubscription::PlanUpgrade < TrialSubscription::Base

  private

    def plan_features
      @plan_features ||=  ::PLANS[:subscription_plans][
        SubscriptionPlan::SUBSCRIPTION_PLANS.key(trial_plan)][:features].dup
    end

    def dashboard_plan?
      DASHBOARD_PLANS.include?(trial_plan)
    end

    def features_list_to_add_data
      ADD_DATA_FEATURES
    end

    def new_plan_has_livechat?
      Subscription::FRESHCHAT_PLANS.include? trial_plan
    end

    def handle_feature_drop_data
      # No features data are required to remove in trial upgrade
    end
end