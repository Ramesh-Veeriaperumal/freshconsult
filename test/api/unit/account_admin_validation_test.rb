require_relative '../unit_test_helper'

class AccountAdminValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_required_params
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', email: 'me@you.we', phone: '0000000')
    assert account_admin_validation.valid?
  end

  def test_absence_of_required_params
    Account.stubs(:current).returns(Account.new)
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(phone: '0000000')
    assert account_admin_validation.invalid?
    require_params_error_messages = { email: 'cannot be blank', first_name: 'cannot be blank', last_name: 'cannot be blank' }
    assert_equal require_params_error_messages, account_admin_validation.errors.to_h
  end

  def test_invalid_email
    Account.stubs(:current).returns(Account.new)
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', email: 'me@you.', phone: '0000000')
    assert account_admin_validation.invalid?
    email_invalid_message = { email: 'Email is invalid' }
    assert_equal email_invalid_message, account_admin_validation.errors.to_h
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', email: 'me', phone: '0000000')
    assert account_admin_validation.invalid?
    assert_equal email_invalid_message, account_admin_validation.errors.to_h
  end
end
