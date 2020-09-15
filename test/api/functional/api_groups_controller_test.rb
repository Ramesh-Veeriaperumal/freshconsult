require_relative '../test_helper'
class ApiGroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper
  include GroupHelper
  include UsersHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include GroupConstants

  def wrap_cname(params)
    { api_group: params }
  end

  def enabling_fsm_feature
    Account.current.add_feature(:field_service_management)
  end

  def revoke_fsm_feature
    Account.current.revoke_feature(:field_service_management)
  end

  def test_update_ticket_assign_type_for_field_group
    @account.add_feature :round_robin
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    create_field_agent_type
    group = create_group(@account, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, group_type: GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME))
    put :update, construct_params({ id: group.id }, escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: true)
    assert_response 400
    res = JSON.parse response.body
    match_json([bad_request_error_pattern('ticket_assign_type', :invalid_field_auto_assign, :code => :invalid_value)])
  ensure
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
    @account.revoke_feature :round_robin
  end

  def test_create_field_group_with_ticket_assign_type
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    create_field_agent_type
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, auto_ticket_assign: true, group_type: FIELD_GROUP_NAME)
    assert_response 400
    res = JSON.parse response.body
    match_json([bad_request_error_pattern('ticket_assign_type', :invalid_field_auto_assign, :code => :invalid_value)])
  ensure
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_create_group
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, auto_ticket_assign: true)
    assert_response 201
    match_json(group_pattern(Group.last))
  end

  def test_create_group_with_group_type
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, group_type: @account.group_types.first.name, auto_ticket_assign: true)
    assert_response 201
    match_json(group_pattern(Group.last))
  end

  def test_create_group_with_invalid_group_type
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, group_type: Faker::Lorem.characters(10), auto_ticket_assign: true)
    assert_response 400
    result = (JSON.parse response.body)["errors"][0]["code"]
    assert_equal result,"invalid_value"
  end

  def test_create_group_with_existing_name
    existing_group = Group.first || create_group(@account)
    post :create, construct_params({}, name: existing_group.name, description: Faker::Lorem.paragraph)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['group_id'], existing_group.id
    match_json([bad_request_error_pattern_with_additional_info('name', additional_info, :'has already been taken')])
  end

  def test_create_group_with_all_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.sentence(2), group_type: GroupConstants::SUPPORT_GROUP_NAME,
                                       escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: true, agent_ids: [1])
    assert_response 201
    match_json(group_pattern({ agent_ids: [1] }, Group.last))
  end

  def test_restrict_group_creation_without_name
    post :create, construct_params({}, name: '', description: Faker::Lorem.paragraph)
    assert_response 400
    match_json([bad_request_error_pattern('name', :blank)])
  end

  def test_create_group_with_invalid_fields
    post :create, construct_params({}, id: 123, business_hour_id: 2,
                                       name: 'TestGroups1', description: Faker::Lorem.paragraph)
    assert_response 400
    match_json([bad_request_error_pattern('id', :invalid_field),
                bad_request_error_pattern('business_hour_id', :invalid_field)])
  end

  def test_create_group_with_invalid_field_values
    post :create, construct_params({}, escalate_to: Faker::Lorem.characters(5),
                                       unassigned_for: Faker::Lorem.characters(5),
                                       name: Faker::Lorem.characters(300), description: Faker::Lorem.paragraph,
                                       auto_ticket_assign: Faker::Lorem.characters(5))
    assert_response 400
    match_json([bad_request_error_pattern('escalate_to', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('unassigned_for', :not_included, list: '30m,1h,2h,4h,8h,12h,1d,2d,3d'),
                bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('auto_ticket_assign', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_group_with_valid_with_trailing_spaces
    post :create, construct_params({}, name: Faker::Lorem.characters(20) + white_space, auto_ticket_assign: true)
    assert_response 201
    match_json(group_pattern({}, Group.last))
  end

  def test_create_group_with_invalid_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agent_ids: ['asd', 'asd1'])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :array_datatype_mismatch, expected_data_type: :'Positive Integer')])
  end

  def test_create_group_with_deleted_or_invalid_agent_id
    agent_id = Faker::Number.between(5000, 10_000)
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agent_ids: [agent_id])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :invalid_list, list: agent_id.to_s)])
  end

  def test_create_field_group_with_field_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    create_field_agent_type
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, unassigned_for: '30m', group_type: FIELD_GROUP_NAME, agent_ids: [agent.id])
    assert_response 201
    match_json(group_pattern(Group.last))
  ensure
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_create_field_group_with_support_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::SUPPORT_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, unassigned_for: '30m', group_type: FIELD_GROUP_NAME, agent_ids: [agent.id])
    assert_response 201
    match_json(group_pattern(Group.last))
  ensure
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_create_support_group_with_field_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_agent_type
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, auto_ticket_assign: true, group_type: SUPPORT_GROUP_NAME, agent_ids: [agent.id])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :should_not_be_field_agent)])
  ensure
    agent.destroy
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_index
    @account.add_feature :round_robin
    Group.delete_all
    3.times do
      create_group(@account)
    end
    get :index, controller_params
    pattern = []
    Account.current.groups.order(:name).all.each do |group|
      pattern << group_pattern_for_index(Group.find(group.id))
    end
    assert_response 200
    match_json(pattern.ordered!)
  ensure
    @account.revoke_feature :round_robin
  end

  def test_index_for_validate_filter_params_valid
    create_field_group_type
    3.times do
      create_group(@account, group_type: GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME))
    end
    group_count = @account.groups.where(group_type: GroupType.group_type_id(GroupConstants::SUPPORT_GROUP_NAME)).count
    get :index, controller_params(group_type: @account.group_types.first.name)
    res = JSON.parse response.body
    assert_equal group_count,res.size
    assert_response 200
  ensure
    destroy_field_group
  end

  def test_index_for_validate_filter_params_invalid
    get :index, controller_params(group_type: Faker::Lorem.characters(10))
    assert_response 400
    result = (JSON.parse response.body)["errors"][0]["code"]
    assert_equal result,"invalid_value"
  end

  def test_show_with_invalid_boolean_value
    group = create_group(@account, ticket_assign_type: 1)
    get :show, construct_params(id: group.id)
    assert_response 200
    match_json(group_pattern(Group.find(group.id)))
  end

  def test_show_group
    group = create_group(@account, ticket_assign_type: 1)
    get :show, construct_params(id: group.id)
    assert_response 200
    match_json(group_pattern(Group.find(group.id)))
  end

  def test_handle_show_request_for_missing_group
    get :show, construct_params(id: 2000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_group_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_delete_group
    group = create_group(@account)
    delete :destroy, construct_params(id: group.id)
    assert_equal ' ', 	@response.body
    assert_response 204
    assert_nil Group.find_by_id(group.id)
  end

  def test_delete_group_with_invalid_id
    delete :destroy, construct_params(id: (1000 + Random.rand(11)))
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_group
    @account.add_feature :round_robin
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: 1, unassigned_for: '30m',
                                                    auto_ticket_assign: true, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: 1,
                               agent_ids: [1] }, group.reload))
  ensure
    @account.revoke_feature :round_robin
  end

  def test_update_group_with_blank_name
    @account.add_feature :round_robin
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, name: '')
    assert_response 400
    match_json([bad_request_error_pattern('name', :blank)])
  ensure
    @account.revoke_feature :round_robin
  end

  def test_update_group_with_invalid_field_values
    @account.add_feature :round_robin
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: Faker::Lorem.characters(5),
                                                    unassigned_for: Faker::Lorem.characters(5),
                                                    name: Faker::Lorem.characters(300), description: Faker::Lorem.paragraph,
                                                    auto_ticket_assign: Faker::Lorem.characters(5))
    assert_response 400
    match_json([bad_request_error_pattern('escalate_to', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('unassigned_for', :not_included, list: '30m,1h,2h,4h,8h,12h,1d,2d,3d'),
                bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('auto_ticket_assign', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  ensure
    @account.revoke_feature :round_robin
  end

  def test_update_group_with_deleted_or_invalid_agent_id
    agent_id = Faker::Number.between(5000, 10_000)
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    post :update, construct_params({ id: group.id }, escalate_to: 898_989, agent_ids: [agent_id])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :invalid_list, list: agent_id.to_s),
                bad_request_error_pattern('escalate_to', :absent_in_db, resource: :agent, attribute: :escalate_to)])
  end

  def test_update_group_valid_with_trailing_spaces
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, name: Faker::Lorem.characters(20) + white_space)
    assert_response 200
    match_json(group_pattern({}, group.reload))
  end

  def test_update_group_with_invalid_id
    put :update, construct_params({ id: Random.rand(9) + 999 }, description: Faker::Lorem.paragraph)
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_agents_of_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ agent_ids: [1] }, group.reload))
  end

  def test_update_field_group_with_field_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    create_field_agent_type
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, group_type: GroupType.group_type_id(FIELD_GROUP_NAME))
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    put :update, construct_params({ id: group.id }, agent_ids: [agent.id])
    assert_response 200
    match_json(group_pattern(Group.last))
  ensure
    agent.destroy
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_update_field_group_with_support_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::SUPPORT_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, group_type: GroupType.group_type_id(FIELD_GROUP_NAME))
    put :update, construct_params({ id: group.id }, agent_ids: [agent.id])
    assert_response 200
    match_json(group_pattern(Group.last))
  ensure
    agent.destroy
    destroy_field_group
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_update_support_group_with_field_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_agent_type
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    put :update, construct_params({ id: group.id }, agent_ids: [agent.id])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :should_not_be_field_agent)])
  ensure
    agent.destroy
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_update_group_type_of_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, group_type: GroupConstants::SUPPORT_GROUP_NAME)
    assert_response 400
    result = (JSON.parse response.body)["errors"][0]["code"]
    assert_equal result,"invalid_field"
  end


  def test_validate_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, agent_ids: [''])
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :array_datatype_mismatch, expected_data_type: :'Positive Integer')])
  end

  def test_delete_existing_agents_while_update
    group = create_group_with_agents(@account, agent_ids: [1, 2, 3], name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ agent_ids: [1] }, group.reload))
  end

  def test_show_group_with_round_robin_disabled
    group = create_group(@account, ticket_assign_type: 0)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    get :show, construct_params(id: group.id)
    @account.class.any_instance.unstub(:features?)
    assert_response 200
    match_json(group_pattern_without_assingn_type(Group.find(group.id)))
  end

  def test_update_auto_ticket_assign_with_round_robin_disabled
    group = create_group_with_agents(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, agent_list: [1, 2, 3])
    @account.class.any_instance.stubs(:features?).returns(false)
    put :update, construct_params({ id: group.id }, auto_ticket_assign: true)
    @account.class.any_instance.unstub(:features?)
    assert_response 400
    match_json([bad_request_error_pattern('auto_ticket_assign', :invalid_field)])
  end

  def test_destroy_all_agents_in_a_group
    group = create_group_with_agents(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, agent_ids: [1, 2, 3], ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, agent_ids: [])
    assert_response 200
    match_json(group_pattern({ agent_ids: nil }, group.reload))
  end

  def test_group_with_pagination_enabled
    3.times do
      create_group(@account)
    end
    get :index, controller_params(per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1, page: 3)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_groups_with_pagination_exceeds_limit
    get :index, controller_params(per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_update_group_with_existing_name
    group1 = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    group2 = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group2.id }, name: group1.name)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['group_id'], group1.id
    match_json([bad_request_error_pattern_with_additional_info('name', additional_info, :'has already been taken')])
  end

  def test_index_with_link_header
    3.times do
      create_group(@account)
    end
    per_page = @account.groups.all.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/groups?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_update_toggle_availability_without_ticket_assignment_without_agent_status_features
    group = create_group(@account)
    put :update, construct_params({ id: group.id }, allow_agents_to_change_availability: true)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  end

  def test_update_toggle_availability_with_ticket_assignment_without_agent_status_feature
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    group = create_group(@account)
    put :update, construct_params({ id: group.id }, allow_agents_to_change_availability: true)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  ensure
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
  end

  def test_update_toggle_availability_with_ticket_assignment_with_agent_status_feature
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    Account.current.launch :agent_statuses
    group = create_group(@account, toggle_availability: false, ticket_assign_type: 1)
    put :update, construct_params({ id: group.id }, allow_agents_to_change_availability: true)
    group.reload
    assert_equal true, group.toggle_availability
    assert_response 200
    match_json(group_pattern({ agent_ids: nil }, group.reload).merge(allow_agents_to_change_availability: true))
  ensure
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    Account.current.rollback :agent_statuses
  end

  def test_update_toggle_availability_without_ticket_assignment_with_agent_status_feature
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    Account.current.launch :agent_statuses
    group = create_group(@account, toggle_availability: false)
    put :update, construct_params({ id: group.id }, allow_agents_to_change_availability: true)
    group.reload
    assert_equal true, group.toggle_availability
    assert_response 200
    match_json(group_pattern_without_assingn_type({ agent_ids: nil }, group.reload).merge(allow_agents_to_change_availability: true))
  ensure
    Account.current.rollback :agent_statuses
  end

  def test_toggle_availability_data_type
    Account.current.launch :agent_statuses
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, agent_ids: [1], allow_agents_to_change_availability: 'true')
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  ensure
    Account.current.rollback :agent_statuses
  end

  def test_update_toggle_availability_with_agent_statuses_with_field_group
    Account.current.launch :agent_statuses
    enabling_fsm_feature
    create_field_group_type
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, group_type: GroupType.group_type_id(FIELD_GROUP_NAME))
    put :update, construct_params({ id: group.id }, allow_agents_to_change_availability: true)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  ensure
    destroy_field_group
    revoke_fsm_feature
    @account.rollback :agent_statuses
  end

  def test_create_with_agent_availability_with_agent_statues_with_field_agent
    @account.launch :agent_statuses
    @account.revoke_feature :round_robin
    @account.revoke_feature :omni_channel_routing
    enabling_fsm_feature
    create_field_group_type
    post :create, construct_params(name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true,
                                   group_type: GroupConstants::FIELD_GROUP_NAME)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  ensure
    destroy_field_group
    revoke_fsm_feature
    @account.rollback :agent_statuses
  end

  def test_index_with_omni_channel_groups
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    ApiGroupsController.any_instance.stubs(:request_service).returns(omni_channel_groups_response)
    get :index, controller_params(include: 'omni_channel_groups', auto_assignment: true)
    assert_response 200
    pattern = []
    Account.current.groups.round_robin_groups.order(:name).each do |group|
      pattern << group_pattern_for_index(Group.find(group.id))
    end
    omni_channel_groups_response['ocr_groups'].each do |channel_group|
      omni_channel_group = omni_channel_groups_pattern(channel_group)
      pattern << omni_channel_group if omni_channel_group.present?
    end
    match_json(pattern)
  ensure
    ApiGroupsController.any_instance.unstub(:request_service)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
    Account.unstub(:current)
  end

  def test_index_with_all_omni_channel_groups
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
    ApiGroupsController.any_instance.stubs(:request_service).returns(omni_channel_groups_response(false))
    get :index, controller_params(include: 'omni_channel_groups')
    assert_response 200
    pattern = []
    Account.current.groups.order(:name).all.each do |group|
      pattern << group_pattern_for_index(Group.find(group.id))
    end
    omni_channel_groups_response['ocr_groups'].each do |channel_group|
      omni_channel_group = omni_channel_groups_pattern(channel_group)
      pattern << omni_channel_group(false) if omni_channel_group.present?
    end
    match_json(pattern)
  ensure
    ApiGroupsController.any_instance.unstub(:request_service)
    Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
    Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
    Account.unstub(:current)
  end
end
