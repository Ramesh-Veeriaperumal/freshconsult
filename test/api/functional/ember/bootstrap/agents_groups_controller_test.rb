require_relative '../../../test_helper'
module Ember
  module Bootstrap
    class AgentsGroupsControllerTest < ActionController::TestCase
      include BootstrapTestHelper
      include AgentsTestHelper

      def test_agents_groups
        skip('failures and errors 21')
        get :index, controller_params(version: 'private')
        assert_response 200

        match_json(agent_group_pattern(Account.current))
      end
    end
  end
end
