require_relative '../../../test_helper'
module Ember
  module Bootstrap
    class PreferencesControllerTest < ActionController::TestCase
      include BootstrapTestHelper
      include AgentsTestHelper

      def wrap_cname(params)
        params
      end

      def test_preferences_show
        agent_data = get :show, controller_params(version: 'private')

        result = JSON.parse(agent_data.body)
        assert_response 200, result

        match_json(@agent.agent.preferences)
      end

      def test_preferencs_update_with_valid_input
        updated_agent = put :update, construct_params(
          { version: 'private' },
          field_service: { dismissed_sample_scheduling_dashboard: true }
        )

        result = JSON.parse(updated_agent.body)
        assert_response 200, result

        match_json(@agent.agent.preferences)
        assert_equal result['field_service']['dismissed_sample_scheduling_dashboard'], true
      end

      def test_preferencs_update_with_loyalty_upgrade
        updated_agent = put :update, construct_params(
          { version: 'private' },
          show_loyalty_upgrade: true
        )

        result = JSON.parse(updated_agent.body)
        assert_response 200, result

        match_json(@agent.agent.preferences)
        assert_equal result['show_loyalty_upgrade'], @agent.agent.show_loyalty_upgrade
      end

      def test_preferencs_update_with_monthly_to_annual_notification
        updated_agent = put :update, construct_params(
          { version: 'private' },
          show_monthly_to_annual_notification: true
        )

        result = JSON.parse(updated_agent.body)
        assert_response 200, result

        match_json(@agent.agent.preferences)
        assert_equal result['show_monthly_to_annual_notification'], @agent.agent.show_monthly_to_annual_notification
      end
    end
  end
end
