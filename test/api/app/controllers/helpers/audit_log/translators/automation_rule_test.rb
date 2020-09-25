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
    condition_data = { condition_data: [{ any: [{ evaluate_on: :ticket, name: 'priority', operator: 'in', value: [1, 2, 3, 4]}]},
                                        { any: [{ evaluate_on: :ticket, name: 'priority', operator: 'in', value: [1, 2]}]}]}
    result = @rule.readable_rule_changes(condition_data)
    assert result[:condition_data][0][:any][0][:name] == 'Priority'
  end

  def test_readable_rule_changes_observer_rule
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    condition_data = { condition_data: [{ performer: {type: '1'}, events: [{ name: 'status', from: 2, to: 4}], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question']}]}},
                                        { performer: {type: '1'}, events: [{ name: 'status', from: 2, to: 4}], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question', 'Problem']}]}}] }
    result = @rule.readable_rule_changes(condition_data)
    assert result[:condition_data][1][:performer][:field] == 'Agent'
  end

  def test_set_rule_type
    @rule.set_rule_type(3)
    assert @rule.instance_variable_get(:@rule_type) == 3
  end

  def test_translate_send_email_to_agent
    assert_nothing_raised do
      action_data = {action_data: [[{ name: 'send_email_to_agent', email_to: 0, email_subject: 'hello!!', email_body: '<p dir=\'ltr\'>test</p>' }],
                                   [{ name: 'send_email_to_agent', email_to: 970104, email_subject: 'hello!!', email_body: '<p dir=\'ltr\'>test</p>' }]] }
      result = @rule.readable_rule_changes(action_data)
      puts result.inspect
    end
  end

  def test_translate_send_email_to_group
    assert_nothing_raised do
      action_data = { action_data: [[{ name: 'send_email_to_group', email_to: 0, email_subject: 'hello!!', email_body: '<p dir=\'ltr\'>test</p>' }],
                                    [{ name: 'send_email_to_group', email_to: 970104, email_subject: 'hello!!', email_body: '<p dir=\'ltr\'>test</p>' }]] }
      result = @rule.readable_rule_changes(action_data)
      puts result.inspect
    end
  end

  def test_readable_rule_changes_observer_rule_with_webhook
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    result = @rule.readable_rule_changes({ condition_data: [ { evaluate_on: :ticket, name: 'supervisor', performer: { field: {}, type: '2'}, events: [ { name: 'trigger_webhook' } ], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question']}]} },
                                                             { evaluate_on: :ticket, name: 'supervisor', performer: { field: {}, type: '3'}, events: [ { name: 'trigger_webhook' } ], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question', 'Problem']}]} } ] })
    assert result[:condition_data][0][:events][0][:value][:name] == 'trigger_webhook'
  end

  def test_readable_rule_changes_observer_rule_for_nested_rules
    @rule = AutomationRuleFakeClass.new(VAConfig::OBSERVER_RULE)
    condition_data = { condition_data: [{ evaluate_on: :ticket, name: 'supervisor', performer: { field: {}, type: '2'}, events: [ { name: 'trigger_webhook', nested_rules: {} } ], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question']}]} },
                                        { evaluate_on: :ticket, name: 'supervisor', performer: { field: {}, type: '3'}, events: [ { name: 'trigger_webhook', nested_rules: {} } ], conditions: { any: [{ evaluate_on: :ticket, name: 'ticket_type', operator: 'in', value: ['Question', 'Problem']}]} }] }
    result = @rule.readable_rule_changes(condition_data)
    assert result[:condition_data][0][:events][0][:value][:name] == 'trigger_webhook'
  end

end
