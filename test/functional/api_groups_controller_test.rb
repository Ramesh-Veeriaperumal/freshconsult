require_relative '../test_helper'
class ApiGroupsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_group: params }
  end

  def test_create_group
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    assert_response :created
    match_json(group_pattern(Group.last))
  end

  def test_create_group_with_existing_name
    post :create, construct_params({}, name: 'TestGroups1', description: Faker::Lorem.paragraph)
    post :create, construct_params({}, name: 'TestGroups1', description: Faker::Lorem.paragraph)
    match_json([bad_request_error_pattern('name', 'has already been taken')])
  end

  def test_create_group_with_all_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.sentence(2),
                                       escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: true, agents: [1])
    assert_response :created
    match_json(group_pattern({ agents: [1] }, Group.last))
  end

  def test_restrict_group_creation_without_name
    post :create, construct_params({}, name: '', description: Faker::Lorem.paragraph)
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_create_group_with_invalid_fields
    post :create, construct_params({}, id: 123, business_calendar_id: 2,
                                       name: 'TestGroups1', description: Faker::Lorem.paragraph)
    match_json([bad_request_error_pattern('id', 'invalid_field'),
                bad_request_error_pattern('business_calendar_id', 'invalid_field')])
  end

  def test_create_group_with_invalid_field_values
    post :create, construct_params({}, escalate_to: Faker::Lorem.characters(5),
                                       unassigned_for: Faker::Lorem.characters(5),
                                       name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       auto_ticket_assign: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('escalate_to', 'is not a number'),
                bad_request_error_pattern('unassigned_for', 'Should be a value in the list 30m,1h,2h,4h,8h,12h,1d,2d,3d,'),
                bad_request_error_pattern('auto_ticket_assign', 'Should be a value in the list true,false')])
  end

  def test_create_group_with_invalid_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agents: ['asd', 'asd1'])
    match_json([bad_request_error_pattern('agents', 'is not a number')])
  end

  def test_create_group_with_deleted_or_invalid_agent_id
    agent_id = Faker::Number.between(5000, 10_000)
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agents: [agent_id])
    match_json([bad_request_error_pattern('agents', 'list is invalid', meta: agent_id.to_s)])
  end

  def test_index_groups
    get :index, request_params
    assert_equal Group.all, assigns(:items)
    assert_equal Group.all, assigns(:api_groups)
  end

  def test_show_group
    group = create_group(@account)
    get :show, construct_params(id: group.id)
    assert_response :success
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
    assert_nil Group.find_by_id(group.id)
  end

  def test_delete_group_with_invalid_id
    delete :destroy, construct_params(id: (1000 + Random.rand(11)))
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: 1, unassigned_for: '30m',
                                                    auto_ticket_assign: true, agents: [1, 2])
    assert_response :success
    match_json(group_pattern({ escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: 1,
                               agents: [1, 2] }, group.reload))
  end

  def test_update_group_with_blank_name
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, name: '')
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_update_group_with_invalid_field_values
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: Faker::Lorem.characters(5),
                                                    unassigned_for: Faker::Lorem.characters(5),
                                                    name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                                    auto_ticket_assign: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('escalate_to', 'is not a number'),
                bad_request_error_pattern('unassigned_for', 'Should be a value in the list 30m,1h,2h,4h,8h,12h,1d,2d,3d,'),
                bad_request_error_pattern('auto_ticket_assign', 'Should be a value in the list true,false')])
  end

  def test_update_group_with_invalid_id
    put :update, construct_params({ id: Random.rand(9) + 999 }, description: Faker::Lorem.paragraph)
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_agents_of_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, agents: [1, 2])
    assert_response :success
    match_json(group_pattern({ agents: [1, 2] }, group.reload))
  end

  def test_validate_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, agents: [''])
    match_json([bad_request_error_pattern('agents', 'is not a number')])
  end

  def test_delete_existing_agents_while_update
    group = create_group_with_agents(@account, agent_list: [1, 2, 3], name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, agents: [1])
    assert_response :success
    match_json(group_pattern({ agents: [1] }, group.reload))
  end

  def test_show_group_with_round_robin_disabled
    group = create_group(@account)
    @account.class.any_instance.stubs(:features_included?).returns(false)
    get :show, construct_params(id: group.id)
    @account.class.any_instance.unstub(:features_included?)
    assert_response :success
    match_json(group_pattern_without_assingn_type(Group.find(group.id)))
  end

  def test_update_auto_ticket_assign_with_round_robin_disabled
    group = create_group_with_agents(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, agent_list: [1, 2, 3])
    @account.class.any_instance.stubs(:features_included?).returns(false)
    put :update, construct_params({ id: group.id }, auto_ticket_assign: true)
    @account.class.any_instance.unstub(:features_included?)
    match_json([bad_request_error_pattern('auto_ticket_assign', 'invalid_field')])
  end

  def test_destroy_all_agents_in_a_group
    group = create_group_with_agents(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, agent_list: [1, 2, 3])
    put :update, construct_params({ id: group.id }, agents: [])
    assert_response :success
    match_json(group_pattern({ agents: [] }, group.reload))
  end
end
