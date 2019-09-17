require_relative '../unit_test_helper'

class MailboxFilterValidationTest < ActionView::TestCase
  def test_valid_v2
    mailbox_filter = Email::MailboxFilterValidation.new(order_by: 'group_id', order_type: 'desc', support_email: 'testtest@fd.com', forward_email: 'fdtest@test.com', active: 'true', product_id: 1, group_id: 1, version: 'v2')
    assert mailbox_filter.valid?
  end

  def test_invalid_support_email_v2
    mailbox_filter = Email::MailboxFilterValidation.new(support_email: '*testtest.com*', version: 'v2')
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(false)
    refute mailbox_filter.valid?
    error = mailbox_filter.errors.full_messages
    assert error.include?('Support email invalid_format')
  ensure
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_valid_private
    mailbox_filter = Email::MailboxFilterValidation.new(order_by: 'group_id', order_type: 'desc', support_email: '*test*', forward_email: 'fdtest@test.com', active: 'true', product_id: 1, group_id: 1, version: 'private')
    Email::MailboxFilterValidation.any_instance.stubs(:private_api?).returns(true)
    assert mailbox_filter.valid?
  ensure
    Email::MailboxFilterValidation.any_instance.unstub(:private_api?)
  end

  def test_invalid_support_email_length
    mailbox_filter = Email::MailboxFilterValidation.new(support_email: '*t*', version: 'private')
    refute mailbox_filter.valid?
    error = mailbox_filter.errors.full_messages
    assert error.include?('Support email too_long_too_short')
  end

  def test_invalid
    mailbox_filter = Email::MailboxFilterValidation.new(order_by: 'test', order_type: 'des', support_email: nil, forward_email: 'testing', active: 1, product_id: 'testing', group_id: 'testing')
    refute mailbox_filter.valid?
    error = mailbox_filter.errors.full_messages
    assert error.include?('Order type not_included')
    assert error.include?('Order by not_included')
    assert error.include?('Product datatype_mismatch')
    assert error.include?('Group datatype_mismatch')
    assert error.include?('Forward email invalid_format')
    assert error.include?('Support email datatype_mismatch')
    assert error.include?('Active datatype_mismatch')
  end
end
