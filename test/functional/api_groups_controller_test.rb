require_relative '../test_helper'
class ApiGroupsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { group: params }
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
                                       escalate_to: 1, assign_time: 2400, ticket_assign_type: 1, agent_list: '1')
    assert_response :created
    match_json(group_pattern({ agent_list: '1' }, Group.last))
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
                                       assign_time: Faker::Lorem.characters(5),
                                       name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       ticket_assign_type: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('escalate_to', 'is not a number'),
                bad_request_error_pattern('assign_time', 'is not a number'),
                bad_request_error_pattern('ticket_assign_type', 'is not a number')])
  end

  def test_create_group_with_invalid_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agent_list: 'asd,asd1')
    match_json([bad_request_error_pattern('agent_list', 'list is invalid', meta: 'asd, asd1')])
  end

  def test_create_group_with_deleted_or_invalid_agent_id
    post :create, construct_params({}, name: Faker::Lorem.characters(5), description: Faker::Lorem.paragraph,
                                       agent_list: Faker::Number.between(5000, 10_000).to_s)
    match_json([bad_request_error_pattern('agent_groups.user', "can't be blank")])
  end

  def test_index_groups
    get :index, request_params
    assert_equal Group.all, assigns(:items)
    assert_equal Group.all, assigns(:groups)
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
    get :show, construct_params(id: Faker::Lorem.characters(5))
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
    assert_response :not_found
  end

  def test_update_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: 1, assign_time: 2400,
                                                    ticket_assign_type: 1, agent_list: '1,2')
    assert_response :success
    match_json(group_pattern({ escalate_to: 1, assign_time: 2400, ticket_assign_type: 1,
                               agent_list: '1,2' }, group.reload))
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
                                                    assign_time: Faker::Lorem.characters(5),
                                                    name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                                    ticket_assign_type: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('escalate_to', 'is not a number'),
                bad_request_error_pattern('assign_time', 'is not a number'),
                bad_request_error_pattern('ticket_assign_type', 'is not a number')])
  end

  def test_update_group_with_invalid_id
    put :update, construct_params({ id: Random.rand(9) + 999 }, description: Faker::Lorem.paragraph)
    assert_equal ' ', @response.body
    assert_response :not_found
  end

  def test_update_agents_of_group
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, agent_list: '1,2')
    assert_response :success
    match_json(group_pattern({ agent_list: '1,2' }, group.reload))
  end

  def test_validate_agent_list
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, agent_list: '')
    match_json([bad_request_error_pattern('agent_list', 'invalid_field')])
  end

  def create_group(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group, name: name)
    group.account_id = account.id
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.save!
    group
  end
end
