require_relative "#{Rails.root}/test/api/unit_test_helper"
require "#{Rails.root}/test/api/helpers/automation/event_validation_test_helper.rb"

module Admin::AutomationRules::Events
  class TicketValidationTest < ActionView::TestCase
    include Automation::EventValidationTestHelper

    def setup
      Account.stubs(:current).returns(Account.new)
    end

    def teardown
      Account.unstub(:current)
      super
    end

    def test_valid_field_from_to
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(valid_from_to_hash, nil, false)
      assert_equal true, event_validation.valid?
    end

    def test_invalid_field_from_to
      params = invalid_from_to_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_missing_field_from_to
      params = missing_from_to_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_extra_field_value_for_from_to_field
      params = extra_field_value_in_case_of_from_to
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_valid_field_value
      Account.any_instance.stubs(:'any_survey_feature_enabled_and_active?').returns(true)
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(valid_field_value_hash, [], 4)
      assert_equal true, event_validation.valid?
      Account.any_instance.unstub(:'any_survey_feature_enabled_and_active?')
    end

    def test_invalid_field_value
      params = invalid_field_value_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_missing_field_valid
      params = missing_field_value_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_extra_field_from_to_for_value_expected_field
      params = extra_field_from_to_in_case_of_value
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_valid_label_field
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(valid_label_type_hash, [], 4)
      assert_equal true, event_validation.valid?
    end

    def test_invalid_label_field
      params = invalid_field_label_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end

    def test_valid_system_event_field
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(valid_system_event_hash, [], 4)
      assert_equal true, event_validation.valid?
    end

    def test_invalid_system_event_field
      params = invalid_system_event_hash
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(params, [], 4)
      assert_equal false, event_validation.valid?
      fields = group_by_field_name(fields)
      assert_equal fields, group_by_error_count(event_validation.errors.to_h.inspect, fields)
      assert_equal fields, group_by_error_count(event_validation.error_options.inspect, fields)
    end
  end
end
