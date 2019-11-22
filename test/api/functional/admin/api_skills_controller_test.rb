require_relative '../../test_helper.rb'
require "#{Rails.root}/test/api/helpers/admin/skills_test_helper.rb"
class Admin::ApiSkillsControllerTest < ActionController::TestCase
  include Admin::SkillConstants
  include Admin::SkillsTestHelper
  include TicketFieldsTestHelper
  include AutomationDelegatorTestHelper

  CUSTOM_FIELD_TYPES = %i[nested_fields custom_dropdown].freeze

  def wrap_cname(params)
    { api_skill: params }
  end

  # create skill with default fields
  CONDITION_FIELDS.each_pair do |resource_type, field_names|
    field_names.each do |field_name|
      define_method "test_skill_create_default_#{resource_type}_#{field_name}" do
        Account.stubs(:current).returns(Account.first)
        skill_request = construct_skill_param(resource_type, field_name)
        post :create, construct_params(skill_request)
        parsed_response = JSON.parse(response.body)
        skill_id = parsed_response['id']
        assert_response(201)
        expected_response = skill_pattern_update_test(Account.current.skills.find(parsed_response['id']))
        Account.current.skills.find_by_id(skill_id).destroy
        match_json(expected_response)
      end
    end
  end

  # create skill with custom fields
  CONDITION_FIELDS.keys.each do |resource_type|
    next if resource_type != :ticket # test_reorder_skill

    CUSTOM_FIELD_TYPES.each do |field_type|
      define_method "test_skill_create_custom_#{resource_type}_#{field_type}" do
        Account.stubs(:current).returns(Account.first)
        create_ticket_custom_field(field_type)
        skill_request = construct_skill_param(resource_type, nil, field_type)
        post :create, construct_params({ version: 'private' }, skill_request)
        parsed_response = JSON.parse(response.body)
        skill_id = parsed_response['id']
        assert_response(201)
        Account.current.skills.find_by_id(skill_id).destroy
      end
    end
  end

  # update skill
  REQUEST_PERMITTED_PARAMS.each do |field_name|
    next if field_name == :rank

    define_method "test_skill_update_#{field_name}" do
      Account.stubs(:current).returns(Account.first)
      skill_request = construct_skill_param(:ticket, :priority)
      post :create, construct_params(skill_request)
      parsed_response = JSON.parse(response.body)
      skill_id = Account.current.skills.find_by_id(parsed_response['id']).id
      assert_response(201)
      value_param = valid_skill_field_value(field_name)
      put :update, construct_params({ id: skill_id }, field_name => value_param)
      assert_response(200)
      expected_response = skill_pattern_update_test(Account.current.skills.find_by_id(skill_id))
      Account.current.skills.find_by_id(skill_id).destroy
      match_json(expected_response)
    end
  end

  # show skill
  def test_skill_show
    Account.stubs(:current).returns(Account.first)
    skill_request = construct_skill_param(:ticket, :priority)
    post :create, construct_params(skill_request)
    assert_response(201)
    parsed_response = JSON.parse(response.body)
    get :show, construct_params({id: parsed_response['id']})
    assert_response(200)
  ensure
    Account.unstub(:current)
  end

  # delete a skill
  def test_destroy_skill
    Account.stubs(:current).returns(Account.first)
    skill_request = construct_skill_param(:ticket, :priority)
    post :create, construct_params(skill_request)
    assert_response(201)
    parsed_response = JSON.parse(response.body)
    skill_id = Account.current.skills.find_by_id(parsed_response['id']).id
    delete :destroy, construct_params({ id: skill_id })
    assert_response(204)
  ensure
    Account.unstub(:current)
  end

  # delete a invalid skill
  def test_destroy_skill_invalid
    Account.stubs(:current).returns(Account.first)
    delete :destroy, construct_params({ id: 0 })
    assert_response(404)
  ensure
    Account.unstub(:current)
  end

  # create skill with invalid condition field values
  def test_create_invalid_skill_param
    Account.stubs(:current).returns(Account.first)
    skill_request = invalid_skill_param
    post :create, construct_params(skill_request)
    assert_response(400)
  ensure
    Account.unstub(:current)
  end

  # reorder skill
  def test_reorder_skill
    Account.stubs(:current).returns(Account.first)
    skill_ids = []
    4.times do
      skill_request = construct_skill_param(:ticket, :priority)
      post :create, construct_params(skill_request)
      assert_response(201)
      parsed_response = JSON.parse(response.body)
      skill_ids << Account.current.skills.find_by_id(parsed_response['id']).id
    end
    position_mapping = get_skill_position
    positions = position_mapping.keys
    first_value = [positions[0], position_mapping[positions[0]]]
    last_value = [positions[1], position_mapping[positions[1]]]
    put :update, construct_params({ id: skill_ids.first }, :rank => last_value[0].to_i)
    assert_response(200)
    position_mapping[first_value[0]] = last_value[1]
    position_mapping[last_value[0]] = first_value[1]
    actual_position_mapping = get_skill_position
    match_custom_json(actual_position_mapping, position_mapping)
  ensure
    Account.current.skills.where(id: skill_ids).destroy_all
    Account.unstub(:current)
  end
end