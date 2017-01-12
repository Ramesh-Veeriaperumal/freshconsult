require_relative '../../test_helper'
class Ember::AgentsControllerTest < ActionController::TestCase
  include AgentsTestHelper

  def wrap_cname(params)
    { agent: params }
  end

  def test_agent_index
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    agents = @account.all_agents.order('users.name')
    pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_show_agent
    sample_agent = @account.all_agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(private_api_agent_pattern(sample_agent))
  end

  def test_show_agent_with_view_contact_privilege_only
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.all_agents.first
    get :show, controller_params(version: 'private', id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_me
    get :me, controller_params(version: 'private')
    assert_response 200
    match_json(private_api_agent_pattern(@agent.agent))
  end
end
