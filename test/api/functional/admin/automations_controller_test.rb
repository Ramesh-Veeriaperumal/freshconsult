require_relative '../../test_helper.rb'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class Admin::AutomationsControllerTest < ActionController::TestCase
  include AutomationTestHelper

  def wrap_cname(params)
    { automation: params }
  end

  def setup
    super
    before_all
  end

  def before_all
    toggle_automation_revamp_feature(true)
  end

  def toggle_automation_revamp_feature(enable)
    enable ? Account.current.launch(:automation_revamp) : 
      Account.current.rollback(:automation_revamp)
  end

  def test_get_observer_rules
    get :index, controller_params(rule_type: VAConfig::RULES[:observer])
    assert_response 200
    rules = Account.current.all_observer_rules
    match_json(rules_pattern(rules))
  end

  def test_get_dispatcher_rules
    get :index, controller_params(rule_type: VAConfig::RULES[:dispatcher])
    assert_response 200
    rules = Account.current.all_va_rules
    match_json(rules_pattern(rules))
  end

  def test_invalid_rule_type
    get :index, controller_params(rule_type: 123)
    assert_response 400
    match_json('code' => 'rule_type_not_allowed',
               'message' => 'Rule type not allowed: 123')
  end

  def test_delete_dispatcher_rule
    va_rule = create_dispatcher_rule
    delete :destroy, 
      controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: va_rule.id)
    assert_response 204
  end

  def test_delete_invalid_dispatcher_rule_id
    delete :destroy, controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: 0)
    assert_response 404
  end

  def test_automation_revamp_feature_not_enabled
    toggle_automation_revamp_feature(false)
    get :index, controller_params(rule_type: VAConfig::RULES[:dispatcher])
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The Automation Revamp feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    toggle_automation_revamp_feature(true)
  end

  def test_create_observer_rule
    va_rule_request = sample_json_for_observer
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }, va_rule_request)

    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id']
    custom_response = parsed_response.slice!('created_at', 'updated_at', 'id', 'position')
    sample_response = set_default_fields(va_rule_request)
    match_custom_json(custom_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_create_dispatcher_rule
    va_rule_request = sample_json_for_dispatcher
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }, va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id']
    custom_response = parsed_response.slice!('created_at', 'updated_at', 'id', 'position')
    sample_response = set_default_fields(va_rule_request)
    match_custom_json(custom_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_automation_revamp_feature_not_enabled_create
    toggle_automation_revamp_feature(false)
    va_rule_request = sample_json_for_observer
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }, va_rule_request)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The Automation Revamp feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    toggle_automation_revamp_feature(true)
  end

  def test_show_for_dispatcher
    va_rule_request = sample_json_for_dispatcher
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }, va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id']
    get :show, controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: va_rule_id)
    assert_response(200)
    custom_response = parsed_response.slice!('created_at', 'updated_at', 'id', 'position')
    sample_response = set_default_fields(va_rule_request)
    match_custom_json(custom_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_show_for_observer
    rule_type = VAConfig::RULES[:observer]
    va_rule_request = sample_json_for_observer
    post :create, construct_params({ rule_type: rule_type }, va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id']
    get :show, controller_params(rule_type: rule_type).merge(id: va_rule_id)
    assert_response(200)
    custom_response = parsed_response.slice!('created_at', 'updated_at', 'id', 'position')
    sample_response = set_default_fields(va_rule_request)
    match_custom_json(custom_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_reorder_from_low_to_higher_index
    rule_type = VAConfig::RULES[:dispatcher]
    4.times do
      va_rule_request = sample_json_for_dispatcher
      post :create, construct_params({ rule_type: rule_type }, va_rule_request)
    end
    position_mapping = get_va_rules_position
    last_position = position_mapping.count
    expected_position_reorder = {}
    position_mapping.keys.each_with_index do |key, index|
      expected_position_reorder.merge!((key.to_i - 1).to_s => position_mapping[key]) if index != 0
    end
    id = position_mapping.values.first
    expected_position_reorder[:last_position] = id
    put :update, construct_params({ rule_type: rule_type, id: id }, { 'position': last_position })
    assert_response(200)
    actual_position_mapping = get_va_rules_position
    match_custom_json(actual_position_mapping, expected_position_reorder)
  end

  def get_va_rules_position
    Account.current.all_va_rules.where('id is not null').inject({}) do |hash, x|
      hash.merge!(x.position.to_s => x.id.to_s)
    end
  end
end
