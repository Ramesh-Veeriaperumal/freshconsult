require_relative '../unit_test_helper'
require_relative '../../api/helpers/email_mailbox_test_helper.rb'

class ActionMailerCallbacksTest < ActiveSupport::TestCase
  include EmailMailboxTestHelper

  def test_get_email_type_txn
    res = ActionMailer::Base.get_email_type 'Reply'
    assert_equal 'TRANSACTION', res
  end

  def test_get_email_type_ntf
    res = ActionMailer::Base.get_email_type 'Internal Email'
    assert_equal 'NOTIFICATION', res
  end

  def test_get_email_type_system
    res = ActionMailer::Base.get_email_type 'Data Backup'
    assert_equal 'SYSTEM', res
  end

  def test_account_type
    Account.first.make_current
    exp = Account.current.subscription.state.upcase
    res = ActionMailer::Base.get_account_type
    assert_equal exp, res
  ensure
    Account.reset_current_account
  end

  def test_account_type_default
    res = ActionMailer::Base.get_account_type
    assert_equal 'MONITORING', res
  end

  def test_set_smtp_settings
    Account.stubs(:current).returns(Account.first)
    mailbox = create_email_config(
      support_email: 'test@test.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      }
    )
    mailbox.active = true
    mailbox.save!
    mail = Mail.new do |m|
      m.from 'test@test.com'
      m.to 'you@test.com'
      m.subject 'This is a test email'
      m.body 'Test email'
    end
    mail.header["X-FD-Account-Id"] = Account.first.id
    mail.header["X-FD-Ticket-Id"] = 1
    mail.header["X-FD-Type"] = 'Reply'
    mail.header["X-FD-Note-Id"] = 1
    Thread.stubs(:current).returns(email_config: mailbox)
    ActionMailer::Base.stubs(:access_token_expired?).returns(true)
    ActionMailer::Base.stubs(:refresh_access_token).returns(true)
    ActionMailer::Base.set_smtp_settings(mail)
    assert_equal mail.delivery_method.settings[:user_name], mailbox.smtp_mailbox.user_name
    assert_equal mail.delivery_method.settings[:authentication], mailbox.smtp_mailbox.authentication
  ensure
    Thread.unstub(:current)
    ActionMailer::Base.unstub(:access_token_expired?)
    ActionMailer::Base.unstub(:refresh_access_token)   
  end
end
