require_relative '../unit_test_helper'

class RoleBulkUpdateValidationTest < ActionView::TestCase

  def test_update_with_invalid_options
    User.stubs(:current).returns(User.first)
    controller_params = { ids: [3], options: [] }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Options blank')

    controller_params = { ids: [3] }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Options missing_field')

    controller_params = { ids: [3], options: {} }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Options blank')

    controller_params = { ids: [3], options: { privileges: {} } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Options select_a_field')

    controller_params = { ids: [3], options: { privileges: { add: [], remove: [] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Options select_a_field')
  ensure
    User.unstub(:current)
  end

  def test_invalid_privileges_validation
    User.stubs(:current).returns(User.first)
    Account.stubs(:current).returns(Account.first)
    controller_params = { ids: [3], options: { privileges: { add: ['random_dummy_priviliege'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Privileges no_matching_privilege')

    controller_params = { ids: [3], options: { privileges: { remove: ['random_dummy_priviliege'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Privileges no_matching_privilege')
  ensure
    User.unstub(:current)
    Account.unstub(:current)
  end


  def test_unauthorized_privileges_without_privilege
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    controller_params = { ids: [3], options: { privileges: { add: ['manage_account'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Privileges invalid_privilege_list')

    controller_params = { ids: [3], options: { privileges: { remove: ['manage_account'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    refute role_validation.valid?
    errors = role_validation.errors.full_messages
    assert errors.include?('Privileges invalid_privilege_list')
  ensure
    User.any_instance.unstub(:privilege?)
    User.unstub(:current)
    Account.unstub(:current)
  end

  def test_unauthorized_privileges_with_privilege
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
    controller_params = { ids: [3], options: { privileges: { add: ['manage_account'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    assert role_validation.valid?
    errors = role_validation.errors.full_messages

    controller_params = { ids: [3], options: { privileges: { remove: ['manage_account'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    assert role_validation.valid?
    errors = role_validation.errors.full_messages
  ensure
    User.any_instance.unstub(:privilege?)
    User.unstub(:current)
    Account.unstub(:current)
  end

  def test_validation_success
    User.stubs(:current).returns(User.first)
    Account.stubs(:current).returns(Account.first)
    controller_params = { ids: [3], options: { privileges: { add: ['view_admin'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    assert role_validation.valid?

    controller_params = { ids: [3], options: { privileges: { remove: ['view_admin'] } } }
    role_validation = RoleBulkUpdateValidation.new(controller_params)
    assert role_validation.valid?
  ensure
    User.unstub(:current)
    Account.unstub(:current)
  end
end
