require_relative '../../../test_helper'

module Channel::V2
  class AgentsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include JwtTestHelper

    def setup
      super
      Account.stubs(:current).returns(Account.first)
      User.stubs(:current).returns(User.first)
    end

    def teardown
      super
    end

    def test_verify_agent_privilege
      set_jwt_auth_header('freshdesk')
      get :verify_agent_privilege, controller_params(version: 'private')
      pattern = { admin: User.current.roles.map(&:name).include?('Account Administrator' || 'Administrator'),
                  allow_agent_to_change_status: User.current.toggle_availability?,
                  supervisor: User.current.privilege?(:manage_availability) }
      match_json(pattern)
      assert_response 200
    end
  end
end
