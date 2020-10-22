class TrialSubscriptionActions::PlanDowngrade < TrialSubscriptionActions::Base

  private

    def reset_plan_features
      features_list.each do |feature| 
        unless account_add_ons.include?(feature)
          reset_settings_dependent_on_feature(feature) if account.launched?(:feature_based_settings) # Resetting all settings dependent on this feature
          account.reset_feature(feature)
        end
      end
      Rails.logger.info "Trial subscriptions : #{account.id} : 
        Rolling back features : #{features_list.inspect}"
      account.save!
    end

    def add_new_plan_features_and_settings
      # No new features will get added in trial downgrade
    end

    def features_list_to_drop_data
      DROP_DATA_FEATURES & features_list
    end

    def dashboard_plan?
      DASHBOARD_PLANS.include?(account.subscription.subscription_plan.name)
    end

    def handle_feature_add_data
      # No features data are required to add in trial downgrade
    end
end