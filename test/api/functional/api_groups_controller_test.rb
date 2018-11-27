require_relative '../test_helper'
class ApiGroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  def wrap_cname(params)
    { api_group: params }
  end

  def test_create_group
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
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
    match_json([bad_request_error_pattern('name', :'has already been taken')])
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
    post :create, construct_params({}, name: Faker::Lorem.characters(20) + white_space)
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

  def test_index
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
  end

  def test_index_for_validate_filter_params_valid
    add_data_to_group_type
    3.times do
      create_group(@account,{},2)
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
    group = create_group(@account)
    group.update_column(:ticket_assign_type, 213)
    get :show, construct_params(id: group.id)
    assert_response 200
    match_json(group_pattern(Group.find(group.id)))
  end

  def test_show_group
    group = create_group(@account)
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
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, escalate_to: 1, unassigned_for: '30m',
                                                    auto_ticket_assign: true, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ escalate_to: 1, unassigned_for: '30m', auto_ticket_assign: 1,
                               agent_ids: [1] }, group.reload))
  end

  def test_update_group_with_blank_name
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, name: '')
    assert_response 400
    match_json([bad_request_error_pattern('name', :blank)])
  end

  def test_update_group_with_invalid_field_values
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
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
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
    group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ agent_ids: [1] }, group.reload))
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
    group = create_group_with_agents(@account, agent_ids: [1, 2, 3], name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: group.id }, agent_ids: [1])
    assert_response 200
    match_json(group_pattern({ agent_ids: [1] }, group.reload))
  end

  def test_show_group_with_round_robin_disabled
    group = create_group(@account)
    @account.class.any_instance.stubs(:features?).returns(false)
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
    group = create_group_with_agents(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, agent_ids: [1, 2, 3])
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
    match_json([bad_request_error_pattern('name', :'has already been taken')])
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
end
