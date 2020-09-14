require './test/api/unit_test_helper'
require './api/app/controllers/helpers/audit_log/translators/automation_rule.rb'

# Stub class to test the logic
class AutomationRuleFakeClass
  include AuditLog::Translators::AutomationRule

  def initialize(rule_type)
    @rule_type = rule_type
  end
end

# Please change/add more tests for all better usecases
class AuditLog::Translators::AutomationRuleTest < ActionView::TestCase
  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @rule = AutomationRuleFakeClass.new(VAConfig::BUSINESS_RULE)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_readable_rule_changes_business_rule
    result = @rule.readable_rule_changes({ condition_data: [any: [{ evaluate_on: 'created_at', name: 'supervisor' }]]})
    assert result[:condition_data][0][0][:name] == 'Hours since created'
  end

  def test_readable_rule_changes_observer_rule
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    result = @rule.readable_rule_changes({ condition_data: [ all: [ { evaluate_on: 'created_at', name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'priority' } ] },
                                                                    { name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'priority' } ] } ] ] })
    assert result[:condition_data][0][:events][0][:name] == 'Priority is changed'
  end

  def test_set_rule_type
    @rule.set_rule_type(3)
    assert @rule.instance_variable_get(:@rule_type) == 3
  end

  def test_translate_send_email_to_agent
    assert_nothing_raised do
      result = @rule.readable_rule_changes({ condition_data: [ any: [{ evaluate_on: 'created_at', name: 'send_email_to_agent' }]] })
      puts result.inspect
    end
  end

  def test_translate_send_email_to_group
    assert_nothing_raised do
      result = @rule.readable_rule_changes({ condition_data: [ any: [ { evaluate_on: 'created_at', name: 'send_email_to_group' } ]] } )
      puts result.inspect
    end
  end

  def test_readable_rule_changes_observer_rule_with_webhook
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    result = @rule.readable_rule_changes({ condition_data: [ any: [{ evaluate_on: 'created_at', name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'trigger_webhook' } ] },
                                                                   { name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'priority' } ] } ] ] })
    assert result[:condition_data][0][:events][0][:value][:name] == 'trigger_webhook'
  end

  def test_readable_rule_changes_observer_rule_for_nested_rules
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    result = @rule.readable_rule_changes({ condition_data: [ all: [{ evaluate_on: 'created_at', name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'trigger_webhook', nested_rules: {} } ] },
                                                                   { name: 'supervisor', performer: { field: {}, type: "2"}, events: [ { name: 'priority', nested_rules: {} } ] } ] ] })
    assert result[:condition_data][0][:events][0][:value][:name] == 'trigger_webhook'
  end

end
