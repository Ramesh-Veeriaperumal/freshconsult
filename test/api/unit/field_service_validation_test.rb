require_relative '../unit_test_helper'

class FieldServiceValidationTest < ActionView::TestCase
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include FieldServiceManagementHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    perform_fsm_operations
    Account.reset_current_account
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
  end

  def teardown
    cleanup_fsm
    Account.unstub(:current)
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_field_agents_can_manage_appointments_data_type_validation
    field_service_management_validator = FieldServiceManagementValidation.new({ field_agents_can_manage_appointments: 'string' }, nil)
    refute field_service_management_validator.valid?(:update_settings)
    errors = field_service_management_validator.errors.full_messages
    assert errors.include?('Field agents can manage appointments datatype_mismatch')
    field_service_management_validator = FieldServiceManagementValidation.new({ field_agents_can_manage_appointments: nil }, nil)
    refute field_service_management_validator.valid?(:update_settings)
    errors = field_service_management_validator.errors.full_messages
    assert errors.include?('Field agents can manage appointments datatype_mismatch')
  end
end
