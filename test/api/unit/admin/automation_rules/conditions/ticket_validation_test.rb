require_relative '../../../../../../test/api/unit_test_helper'
require_relative '../../../../helpers/automation/condition_validation_test_helper'

module Admin::AutomationRules::Conditions
  class TicketValidationTest < ActionView::TestCase
    include Automation::ConditionValidationTestHelper
    include Admin::Automation::CustomFieldHelper

    # invalid test
    def test_invalid_ticket_conditions
      Account.stubs(:current).returns(Account.first)
      params = rule_params(condition_params('subjects', :text))
      cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                    custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                    custom_company_condition: custom_condition_company }
      validation = automation_validation_class.new(params, cf_fields, nil, false)
      assert validation.invalid?
    ensure
      Account.unstub(:current)
    end

    # valid default fields test
    VALUE_HASH.keys.each do |type|
      next if %i[choicelist date].include?(type)

      define_method "test_valid_#{type}_fields" do
        Account.stubs(:current).returns(Account.first)
        params = construct_default_params(type)
        cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                      custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                      custom_company_condition: custom_condition_company }
        validation = automation_validation_class.new(params, cf_fields, nil, false)
        assert validation.valid?
        Account.unstub(:current)
      end
    end

    # negative test
    INVALID_HASH.each do |invalid|
      define_method "test_invalid_#{invalid[:field_type]}_fields" do
        Account.stubs(:current).returns(Account.first)
        params = rule_params(condition_params(invalid[:name], invalid[:field_type].to_sym, invalid[:value]))
        cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                      custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                      custom_company_condition: custom_condition_company }
        validation = automation_validation_class.new(params, cf_fields, nil, false)
        assert validation.invalid?
        Account.unstub(:current)
      end
    end
  end
end
