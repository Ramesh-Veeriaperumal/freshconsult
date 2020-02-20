require_relative '../../../unit_test_helper'
require_relative '../../../helpers/ticket_fields_test_helper'
require "#{Rails.root}/test/api/helpers/automation_delegator_test_helper.rb"
['company_fields_test_helper.rb', 'contact_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module Admin::AutoAutomationRules
  class AutomationDelegatorTest < ActionView::TestCase
    include AutomationDelegatorTestHelper
    include TicketFieldsTestHelper
    include CompanyFieldsTestHelper
    include ContactFieldsTestHelper
    include Admin::AutomationConstants

    # test valid ticket default fields
    DEFAULT_TICKET_FIELD_VALUES.each do |field|
      define_method "test_valid_#{field[:field_name]}_ticket_params" do
        Account.stubs(:current).returns(Account.first)
        params = construct_delegator_params(field[:field_name], 'ticket')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end

    # test valid contact default fields
    DEFAULT_CONTACT_FIELD_VALUES.each do |field|
      define_method "test_valid_#{field[:field_name]}_contact_params" do
        Account.stubs(:current).returns(Account.first)
        params = construct_delegator_params(field[:field_name], 'contact')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end

    # test valid company default fields
    DEFAULT_COMPANY_FIELD_VALUES.each do |field|
      define_method "test_valid_#{field[:field_name]}_company_params" do
        Account.stubs(:current).returns(Account.first)
        params = construct_delegator_params(field[:field_name], 'company')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end

    # test valid ticket custom fields
    CUSTOM_FIELD_CONDITION_HASH.keys.each do |field_type|
      define_method "test_valid_custom_field_#{field_type}_ticket_params" do
        Account.stubs(:current).returns(Account.first)
        @account = Account.current
        create_ticket_custom_field(field_type)
        params = construct_custom_field_params(field_type, 'ticket')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end

    def test_valid_custom_decimal_field_number_params
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      create_ticket_custom_field(:custom_decimal)
      params = { name: 'delegator test', active: true,
                 conditions: [{ name: 'condition_set_1', match_type: 'any', properties: [{ resource_type: 'ticket', field_name: 'priority', operator: 'in', value: [1] }] }],
                 actions: [{ field_name: 'cf_custom_decimal', value: 2 }] }
      automation_delegator_class.new(params, params, 1)
      Account.unstub(:current)
    end

    # test valid custom company fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      define_method "test_valid_custom_field_#{field_type}_company_params" do
        Account.stubs(:current).returns(Account.first)
        @account = Account.current
        cf_params = cf_params(type: field_type, field_type: "custom_#{field_type}",
                              label: "test_custom_#{field_type}", editable_in_signup: 'true')
        create_custom_contact_field(cf_params)
        params = construct_customer_params(field_type, 'company')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end

    # test valid custom contact fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      define_method "test_valid_custom_field_#{field_type}_contact_params" do
        Account.stubs(:current).returns(Account.first)
        @account = Account.current
        cf_params = cf_params(type: field_type, field_type: "custom_#{field_type}",
                              label: "test_custom_#{field_type}", editable_in_signup: 'true')
        create_custom_contact_field(cf_params)
        params = construct_customer_params(field_type, 'contact')
        automation_delegator_class.new(params, params, 1)
        Account.unstub(:current)
      end
    end
  end
end
