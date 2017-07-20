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
    agents = @account.agents.order('users.name')
    pattern = agents.map { |agent| private_api_agent_pattern(agent) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_only_filter
    create_rr_agent
    agents = @account.agents.order('users.name')
    # livechat_pattern = agents.map { |agent| livechat_agent_availability(agent) }.to_h
    # Ember::AgentsController.any_instance.stubs(:get_livechat_agent_details).returns(livechat_pattern)
    round_robin_groups = Group.round_robin_groups.map(&:id)
    get :index, controller_params(version: 'private', only: 'available')
    assert_response 200
    pattern = agents.map { |agent| agent_availability_pattern(agent, round_robin_groups) }
    match_json(pattern.ordered)
  end

  def test_agent_index_with_only_filter_count
    create_rr_agent
    # Ember::AgentsController.any_instance.stubs(:available_chat_agents).returns(0)
    json = get :index, controller_params(version: 'private', only: 'available_count')
    assert_response 200
    pattern = agent_availability_count_pattern
    assert_equal json.api_meta, pattern[:meta]
  end

  def test_agent_index_with_only_filter_wrong_params
    create_rr_agent
    round_robin_groups = Group.round_robin_groups.map(&:id)
    Ember::AgentsController.any_instance.stubs(:available_chat_agents).returns(0)
    json = get :index, controller_params(version: 'private', only: 'wrong_params')
    assert_response 400
    match_json([bad_request_error_pattern('only', :not_included, list: 'available,available_count')])
  end

  def test_update_with_availability
    user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    params_hash = { ticket_assignment: { available: false } }
    put :update, construct_params({ version: 'private', id: user.id }, params_hash)
    assert_response 200
    match_json(private_api_agent_pattern(user.agent))
  end

  def test_show_agent
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(private_api_agent_pattern(sample_agent))
  end

  def test_show_agent_with_view_contact_privilege_only
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.agents.first
    get :show, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_show_agent_achievements
    sample_agent = @account.agents.first
    get :achievements, construct_params(version: 'private', id: sample_agent.user.id)
    assert_response 200
    match_json(agent_achievements_pattern(sample_agent))
  end

  def test_me
    get :me, controller_params(version: 'private')
    assert_response 200
    match_json(private_api_agent_pattern(@agent.agent))
  end
end
