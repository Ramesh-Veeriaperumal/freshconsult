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

    def teardown
      Account.unstub(:current)
      super
    end

    def stub_account
      Account.stubs(:current).returns(Account.first)
    end

    def test_dispatchr_valid
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      param_hash = valid_dispatchr_hash(Account.current.products.map(&:id).first)
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 1)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end

    def test_dispatchr_invalid
      Account.stubs(:current).returns(Account.first)
      param_hash = invalid_dispatchr_hash
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 1)
      assert delegator.invalid?
    ensure
      Account.unstub(:current)
    end

    def test_observer_valid
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      param_hash = valid_observer_hash(Account.current.products.map(&:id).first)
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end

    def test_observer_invalid
      Account.stubs(:current).returns(Account.first)
      param_hash = invalid_observer_hash
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.invalid?
    ensure
      Account.unstub(:current)
    end

    def test_valid_contact_condition
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      get_custom_contact_fields
      param_hash = valid_rule(valid_performer, valid_event, 'contact', valid_action)
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end

    def test_valid_company_condition
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      get_custom_company_fields
      param_hash = valid_rule(valid_performer, valid_event, 'company', valid_action)
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end

    def test_valid_nested_array
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      param_hash = valid_observer_array_hash
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end

    def test_invalid_nested_array
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      param_hash = invalid_observer_array_hash
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.invalid?
    ensure
      Account.unstub(:current)
    end

    def test_valid_nested_field_keys
      Account.stubs(:current).returns(Account.first)
      get_all_custom_fields
      create_products(Account.current)
      create_tags_data(Account.current)
      get_a_dropdown_custom_field
      get_a_nested_custom_field
      param_hash = valid_observer_array_hash
      delegator = Admin::AutomationRules::AutomationDelegator.new(param_hash, param_hash, 4)
      assert delegator.valid?
    ensure
      Account.unstub(:current)
    end
  end
end
