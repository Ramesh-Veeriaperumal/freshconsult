require_relative '../../test_helper'
class Ember::AgentPasswordPoliciesControllerTest < ActionController::TestCase

  include UsersTestHelper

  def test_password_policy_for_admin
    get :index, controller_params(version: 'private')
    match_json(password_policy_pattern('agent'))
    assert_response 200
  end

  def test_password_policy_for_restricted_agent
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :index, controller_params(version: 'private')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end
end
