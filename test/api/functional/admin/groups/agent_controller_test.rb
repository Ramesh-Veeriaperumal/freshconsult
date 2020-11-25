require_relative '../../../test_helper'
class Admin::Groups::AgentsControllerTest < ActionController::TestCase
  include GroupsTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
  end

  def wrap_cname(params)
    { agents: params }
  end

  def test_index_for_group_agents
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(version: 'private', id: group.id)
        assert_response 200
        response = JSON.parse(@response.body)
        match_json(group_agent_list_pattern(response))
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_index_for_group_agents_without_feature_enabled
    agent1 = add_test_agent(Account.current)
    group = create_group_private_api(Account.current, agent_ids: [agent1.id])
    get :index, controller_params(version: 'private', id: group.id)
    assert_response 403
  ensure
    group.destroy if group.present?
    agent1.destroy if agent1.present?
  end

  def test_index_for_group_agents_with_invalid_group_id
    enable_group_management_v2 do
      group_id = 10_000_001
      skip if Account.current.groups.where(id: group_id).first.present?
      get :index, controller_params(version: 'private', id: group_id)
      assert_response 404
    end
  end

  def test_index_for_group_agents_with_per_page_greater_than_limit
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(version: 'private', id: group.id, per_page: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 4)
        assert_response 400
        match_json(description: 'Validation failed', errors: [{ field: 'per_page', message: 'It should be a Positive Integer less than or equal to 100', code: 'invalid_value' }])
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_index_for_group_agents_with_pagination
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id, agent2.id, agent3.id])
        get :index, controller_params(version: 'private', id: group.id, per_page: 2)
        assert_response 200
        response = JSON.parse(@response.body)
        assert_equal response.size, 2
        match_json(group_agent_list_pattern(response))
        assert_include @response.headers['Link'], "/api/_/admin/groups/#{group.id}/agents?per_page=2&page=2"
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_index_public_for_group_agents
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(id: group.id)
        assert_response 200
        response = JSON.parse(@response.body)
        match_json(group_agent_list_pattern(response))
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_groups_index_with_include_option
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(id: group.id, include: 'roles')
        assert_response 200
        response = JSON.parse(@response.body)
        match_json(group_agent_list_pattern(response, include_option = 'roles'))
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_groups_index_with_invalid_include_option
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(id: group.id, include: 'asysgdt')
        assert_response 400
        match_json([bad_request_error_pattern('include', :not_included, list: AgentConstants::GROUP_AGENT_INCLUDE_PARAMS.join(', '))])
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_index_public_for_group_agents_without_feature_enabled
    agent1 = add_test_agent(Account.current)
    group = create_group_private_api(Account.current, agent_ids: [agent1.id])
    get :index, controller_params(id: group.id)
    assert_response 403
  ensure
    group.destroy if group.present?
    agent1.destroy if agent1.present?
  end

  def test_index_public_for_group_agents_with_invalid_group_id
    enable_group_management_v2 do
      group_id = 10_000_001
      skip if Account.current.groups.where(id: group_id).first.present?
      get :index, controller_params(id: group_id)
      assert_response 404
    end
  end

  def test_index_public_for_group_agents_with_per_page_greater_than_limit
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        get :index, controller_params(id: group.id, per_page: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 4)
        assert_response 400
        match_json(description: 'Validation failed', errors: [{ field: 'per_page', message: 'It should be a Positive Integer less than or equal to 100', code: 'invalid_value' }])
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
      end
    end
  end

  def test_index_public_for_group_agents_with_pagination
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id, agent2.id, agent3.id])
        get :index, controller_params(id: group.id, per_page: 2)
        assert_response 200
        response = JSON.parse(@response.body)
        assert_equal response.size, 2
        match_json(group_agent_list_pattern(response))
        assert_include @response.headers['Link'], "/api/v2/admin/groups/#{group.id}/agents?per_page=2&page=2"
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_with_removing_agent_from_group_agents
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id, agent2.id, agent3.id])
        patch_hash = [{ id: agent1.id, deleted: true }, { id: agent2.id, deleted: true }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 204
        group = group.reload
        remain_user_ids = group.all_agent_groups.pluck(:user_id)
        assert_equal remain_user_ids.count, 1
        assert_equal  remain_user_ids[0], agent3.id
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_with_adding_agent_from_group_agents
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        patch_hash = [{ id: agent2.id, deleted: false }, { id: agent3.id }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 204
        group = group.reload
        remain_user_ids = group.all_agent_groups.pluck(:user_id)
        assert_equal remain_user_ids.count, 3
        assert_equal remain_user_ids.sort, [agent1.id, agent2.id, agent3.id].sort
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_with_adding_nd_removing_agent_from_group_agents
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        patch_hash = [{ id: agent1.id, deleted: true }, { id: agent2.id }, { id: agent3.id }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 204
        group = group.reload
        remain_user_ids = group.all_agent_groups.pluck(:user_id)
        assert_equal remain_user_ids.count, 2
        assert_equal remain_user_ids.sort, [agent2.id, agent3.id].sort
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_with_true_write_access_for_group_agent
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        patch_hash = [{ id: agent2.id, write_access: true }, { id: agent3.id, write_access: true, deleted: false }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 204
        group = group.reload
        remain_user_ids = group.all_agent_groups.pluck(:user_id)
        assert_equal remain_user_ids.count, 3
        assert_equal remain_user_ids.sort, [agent1.id, agent2.id, agent3.id].sort
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_with_false_invalid_write_access_for_group_agent
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        patch_hash = [{ id: agent2.id, write_access: false }, { id: agent3.id }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 400
        error_data = [bad_request_error_pattern_with_nested_field(:agents, :write_access, :not_included, list: [true].join(','))]
        match_json(description: 'Validation failed', errors: error_data)
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_invalid_params_for_group_agent
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        patch_hash = [{ id: agent2.id }, { id: agent3.id, test: true }]
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 400
        match_json([bad_request_error_pattern('agents[1]', :not_included, list: 'id,write_access,deleted')])
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  def test_patch_invalid_user_id_for_group_agent
    enable_group_management_v2 do
      begin
        agent1 = add_test_agent(Account.current)
        agent2 = add_test_agent(Account.current)
        agent3 = add_test_agent(Account.current)
        group = create_group_private_api(Account.current, agent_ids: [agent1.id])
        user_id = 1_223_232
        patch_hash = [{ id: user_id }]
        group.reload
        skip if group.all_agent_groups.where(user_id: user_id).first.present?
        process(:update, construct_params({ id: group.id }, patch_hash), nil, nil, 'PATCH')
        assert_response 400
        match_json([bad_request_error_pattern(:invalid_agent_ids, :invalid_list, list: user_id.to_s)])
      ensure
        group.destroy if group.present?
        agent1.destroy if agent1.present?
        agent2.destroy if agent2.present?
        agent3.destroy if agent3.present?
      end
    end
  end

  private

    def enable_group_management_v2
      Account.current.launch :group_management_v2
      yield
    ensure
      Account.current.rollback :group_management_v2
    end

    def group_agent_list_pattern(response, include_option = nil)
      pattern = []
      response.each do |agent_details|
        agent = Account.current.users.where(id: agent_details['id']).first.agent
        agent_hash = { id: Integer, ticket_scope: Integer, write_access: agent_details['write_access'], role_ids: agent.user.roles.map(&:id), contact: contact_hash(agent.user), created_at: String, updated_at: String }
        agent_hash[:freshcaller_agent] = agent_details['freshcaller_agent'] if Account.current.freshcaller_enabled?
        agent_hash[:freshchat_agent] = agent_details['freshchat_agent'] if Account.current.omni_chat_agent_enabled?
        agent_hash[:roles] = agent.user.roles.map { |role| { id: role.id, name: role.name } } if AgentConstants::GROUP_AGENT_INCLUDE_PARAMS.include?(include_option)
        pattern << agent_hash
      end
      pattern
    end

    def contact_hash(user)
      { name: user.name, avatar: avatar_hash(user), email: user.email }
    end

    def avatar_hash(user)
      avatar = user.avatar
      return {} unless avatar

      AttachmentDecorator.new(avatar).to_hash
    end
end
