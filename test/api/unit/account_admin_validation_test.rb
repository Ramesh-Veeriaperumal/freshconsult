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

  def test_required_params_with_invoice_email
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: ['me@you.we'])
    assert account_admin_validation.valid?
  end

  def test_absence_of_required_params
    Account.stubs(:current).returns(Account.new)
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(phone: '0000000')
    assert account_admin_validation.invalid?
    require_params_error_messages = { email: :missing_field, first_name: 'cannot be blank', last_name: 'cannot be blank' }
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

  def test_invalid_invoice_email
    Account.stubs(:current).returns(Account.new)
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: 'me@you.com', phone: '0000000')
    assert account_admin_validation.invalid?
    invoice_email_invalid_message = { invoice_emails: :datatype_mismatch }
    assert_equal invoice_email_invalid_message, account_admin_validation.errors.to_h
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: ['me@you.'], phone: '0000000')
    assert account_admin_validation.invalid?
    invoice_email_invalid_message = { invoice_emails: 'Email is invalid' }
    assert_equal invoice_email_invalid_message, account_admin_validation.errors.to_h
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: ['me@you.com', 'you@me.com'], phone: '0000000')
    assert account_admin_validation.invalid?
    invoice_email_invalid_message = { invoice_emails: :too_long }
    assert_equal invoice_email_invalid_message, account_admin_validation.errors.to_h
  end

  def test_valid_company_name_string
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: ['me@you.we'], company_name: 'test')
    assert account_admin_validation.valid?
  end

  def test_valid_company_name_integer
    Account.stubs(:current).returns(Account.new)
    account_admin_validation = AccountAdminValidation.new(first_name: 'me', last_name: 'you', invoice_emails: ['me@you.we'], company_name: 1)
    assert account_admin_validation.valid?
  end
end
