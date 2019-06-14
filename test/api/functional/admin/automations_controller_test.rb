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

  def test_get_dispatcher_rules
    get :index, controller_params(rule_type: VAConfig::RULES[:dispatcher])
    assert_response 200
    rules = Account.current.all_va_rules
    match_json(rules_pattern(rules))
  end

  def test_invalid_rule_type
    get :index, controller_params(rule_type: 123)
    assert_response 404
    match_json('code' => 'rule_type_not_allowed',
               'message' => 'Rule type not allowed: 123')
  end

  def test_delete_dispatcher_rule
    va_rule_request = sample_json_for_dispatcher
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    rule_id = parsed_response['id'].to_i
    delete :destroy,
      controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: rule_id)
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
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)

    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_create_dispatcher_rule
    va_rule_request = sample_json_for_dispatcher
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_automation_revamp_feature_not_enabled_create
    toggle_automation_revamp_feature(false)
    va_rule_request = sample_json_for_observer
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The Automation Revamp feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    toggle_automation_revamp_feature(true)
  end

  def test_show_for_dispatcher
    va_rule_request = sample_json_for_dispatcher
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    get :show, controller_params(rule_type: VAConfig::RULES[:dispatcher]).merge(id: va_rule_id)
    assert_response(200)
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_show_for_observer
    rule_type = VAConfig::RULES[:observer]
    va_rule_request = sample_json_for_observer
    post :create, construct_params({ rule_type: rule_type }.merge(va_rule_request), va_rule_request)
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    get :show, controller_params(rule_type: rule_type).merge(id: va_rule_id)
    assert_response(200)
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rules = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rules.destroy if va_rules.present?
  end

  def test_reorder_rules
    rule_type = VAConfig::RULES[:dispatcher]
    created_ids = create_rules(10, rule_type)
    passed = true
    test_cases = Random.new.rand(2..5)
    test_cases.times do
      rules = get_va_rules_position
      rule_id = rules.to_a.sample[0] # get random id
      new_visual_position = Random.new.rand(1..rules.count) # re-ordering randomly
      pos_should_be = rules.to_a[new_visual_position - 1][1]  # after update rule should have this position
      put :update, construct_params({ rule_type: rule_type, id: rule_id }, { 'position': new_visual_position })
      assert_response 200
      position_is = Account.current.va_rules.find(rule_id).position
      passed = false unless position_is.to_i == pos_should_be.to_i
      break unless passed
    end
    assert passed
  ensure
    Account.current.account_va_rules.where(id: created_ids).destroy_all
  end

  def test_create_observer_rule_with_thank_you_note_feature_disabled
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(false)
    va_rule_request = observer_rule_json_with_thank_you_note
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 403
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'freddy_suggestion[:condition]',
          'message': 'The detect_thank_you_note feature(s) is/are not supported in your plan. Please upgrade your account to use it.',
          'code': 'access_denied'
        }
      ]
    })
  end

  def test_create_observer_rule_with_thank_you_note_feature_enabled
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(va_rule_id)
    sample_response = automation_rule_pattern(rule)
    match_custom_json(parsed_response, sample_response)
  ensure
    va_rule = Account.current.account_va_rules.find_by_id(va_rule_id)
    va_rule.destroy if va_rule.present?
  end

  def test_create_observer_rule_with_thank_you_note_wrong_performer
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    va_rule_request['performer']['type'] = 1
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'conditions[:condition_set_1][:ticket][:freddy_suggestion][2]',
          'message': "Thank you note in condition can only be used for 'add private note/reply sent' events performed by customer",
          'code': 'invalid_value'
        }
      ]
    })
  end

  def test_create_observer_rule_with_thank_you_note_wrong_event
    Account.current.stubs(:detect_thank_you_note_enabled?).returns(true)
    va_rule_request = observer_rule_json_with_thank_you_note
    va_rule_request['events'] = [
      {
        'field_name': 'priority',
        'from': '--',
        'to': '--'
      }
    ]
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    match_json({
      'description': 'Validation failed',
      'errors': [
        {
          'field': 'conditions[:condition_set_1][:ticket][:freddy_suggestion][2]',
          'message': "Thank you note in condition can only be used for 'add private note/reply sent' events performed by customer",
          'code': 'invalid_value'
        }
      ]
      })
  end

end
