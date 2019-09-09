require_relative '../../../../../../test/api/unit_test_helper'
require_relative '../../../../helpers/automation/condition_validation_test_helper'

module Admin::AutomationRules::Conditions
  class CompanyValidationTest < ActionView::TestCase
    include Automation::ConditionValidationTestHelper
    include Admin::Automation::CustomFieldHelper

    # invalid params test
    def test_invalid_company_params
      Account.stubs(:current).returns(Account.first)
      params = rule_params(condition_params('industries', :object_id))
      cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                    custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                    custom_company_condition: custom_condition_company }
      validation = automation_validation_class.new(params, cf_fields, nil, false)
      assert validation.invalid?
    ensure
      Account.unstub(:current)
    end

    # valid default fields test
    COMPANY_FIELD_TYPES.each do |type|
      define_method "test_valid_#{type}_fields" do
        Account.stubs(:current).returns(Account.first)
        params = construct_customer_params(type, :company)
        cf_fields = { custom_ticket_event: custom_event_ticket_field, custom_ticket_action: custom_action_ticket_field,
                      custom_ticket_condition: custom_condition_ticket_field, custom_contact_condition: custom_condition_contact,
                      custom_company_condition: custom_condition_company }
        validation = automation_validation_class.new(params, cf_fields, nil, false)
        assert validation.valid?
        Account.unstub(:current)
      end
    end
  end
end
