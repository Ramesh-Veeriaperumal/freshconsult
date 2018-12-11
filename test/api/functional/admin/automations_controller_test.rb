require_relative '../../test_helper.rb'

class Admin::AutomationsControllerTest < ActionController::TestCase
  include AutomationTestHelper
  
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
    match_json({"description": "Validation failed",
                "errors": [{"field": "rule_type","message": "Rule type not allowed: 123",
                              "code": "invalid_value"}]
      })
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
    match_json({"code" => "require_feature",
                "message" => "The Automation Revamp feature(s) is/are not supported in your plan. Please upgrade your account to use it."})
  ensure
    toggle_automation_revamp_feature(true)
  end
end
