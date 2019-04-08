module Integrations::AdvancedTicketing
  module AdvFeatureMethods

    private

    def current_account
      @account ||= Account.current
    end

    def fetch_advanced_features feature
      @advanced_feature ||= current_account.safe_send("#{feature}_toggle_enabled?")
    end

    def add_feature feature
      Rails.logger.info "Enable feautre :: #{feature}"
      current_account.add_feature(feature)
      NewPlanChangeWorker.perform_async({:features => [feature], :action => "add"})
    end

    def remove_feature feature
      Rails.logger.info "Disable feautre :: #{feature}"      
      current_account.revoke_feature(feature)
      NewPlanChangeWorker.perform_async({:features => [feature], :action => "drop"})
    end
  end
end
