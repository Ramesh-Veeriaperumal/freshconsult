module Ember
  class FreddyController < ApiApplicationController
    include ::Freddy::Util
    include ::Freddy::BulkCreateBot
    skip_before_filter :load_object

    def execute
      append_url = request.url.split('autofaq/').last
      url = "#{FreddySkillsConfig[:system42][:host]}#{SYSTEM42_NAMESPACE}#{append_url}"
      perform(url, :system42)
      render status: @proxy_response.code, json: @parsed_response.to_json
    end

    def bulk_create_bot
      change_plan_to_omnichannel
      bulk_create_bot_perform(action: :autofaq)
      render status: @proxy_response.code, json: @proxy_response.parsed_response.to_json
    end

    private

      def feature_name
        FeatureConstants::AUTOFAQ
      end

      def change_plan_to_omnichannel
        if current_account.subscription.trial? && current_account.subscription.plan_name == SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_19]
          plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_omni_jan_19])
          current_account.subscription.update_attributes(subscription_plan: plan)
        end
      end
  end
end
