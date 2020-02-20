require_relative '../../../../../../test/api/unit_test_helper'
require_relative '../../../../helpers/automation/condition_validation_test_helper'
require_relative '../../../../helpers/ticket_fields_test_helper'

module Admin::AutomationRules::Actions
  class TicketValidationTest < ActionView::TestCase
    include Automation::ConditionValidationTestHelper
    include Admin::CustomFieldHelper
    include Admin::EventCustomFieldHelper
    include Admin::ActionCustomFieldHelper
    include TicketFieldsTestHelper

    def setup
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
    end

    def teardown
      Account.unstub(:current)
    end

    def test_number_field_invalid_datatype_string
      custom_number_field = create_custom_field('test_custom_number', 'number')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_number_field.name), value: 'str' }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.invalid?
    end

    def test_number_field_invalid_datatype_boolean
      custom_number_field = create_custom_field('test_custom_number', 'number')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_number_field.name), value: true }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.invalid?
    end

    def test_number_field_valid_datatype_integer
      custom_number_field = create_custom_field('test_custom_number', 'number')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_number_field.name), value: 2 }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.valid?
    ensure
      Account.unstub(:current)
    end

    def test_decimal_field_invalid_datatype_string
      custom_decimal_field = create_custom_field('test_custom_decimal', 'decimal')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_decimal_field.name), value: 'str' }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.invalid?
    end

    def test_decimal_field_invalid_datatype_boolean
      custom_decimal_field = create_custom_field('test_custom_decimal', 'decimal')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_decimal_field.name), value: true }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.invalid?
    end

    def test_decimal_field_valid_datatype_float
      custom_decimal_field = create_custom_field('test_custom_decimal', 'decimal')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_decimal_field.name), value: 2.5 }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.valid?
    ensure
      Account.unstub(:current)
    end

    def test_integer_for_decimal_field_valid
      custom_decimal_field = create_custom_field('test_custom_decimal', 'decimal')
      params = { name: 'test rule', active: true,
                 actions: [{ field_name: TicketDecorator.display_name(custom_decimal_field.name), value: 2 }] }
      validation = automation_validation_class.new(params, { custom_ticket_action: custom_action_ticket_field }, nil, false)
      assert validation.valid?
    ensure
      Account.unstub(:current)
    end

    private

      def automation_validation_class
        'Admin::AutomationValidation'.constantize
      end
  end
end
