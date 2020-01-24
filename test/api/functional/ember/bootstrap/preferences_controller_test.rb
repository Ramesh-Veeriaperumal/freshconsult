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
    end
  end
end
