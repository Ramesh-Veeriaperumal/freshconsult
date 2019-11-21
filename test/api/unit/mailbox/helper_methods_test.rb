require_relative '../../unit_test_helper'
require_relative '../../../api/helpers/email_mailbox_test_helper.rb'
['helper_methods.rb'].each { |file| require Rails.root.join("lib/mailbox/#{file}") }

class Email::Mailbox::HelperMethodsTest < ActiveSupport::TestCase
  include Mailbox::HelperMethods
  include EmailMailboxTestHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_decrypt_password
    mailbox = create_email_config(
      support_email: 'test@test1.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.save!
    decrtpted_password = decrypt_password(mailbox.smtp_mailbox.password)
    assert_equal decrtpted_password, 'password'
  ensure
    mailbox.destroy
  end

  def test_decrypt_refresh_token
    mailbox = create_email_config(
      support_email: 'test@test2.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.save!
    decrtpted_refresh_token = decrypt_refresh_token(mailbox.smtp_mailbox.refresh_token)
    assert_equal decrtpted_refresh_token, 'refreshtoken'
  ensure
    mailbox.destroy
  end

  def test_set_account
    mailbox = create_email_config(
      support_email: 'test@test3.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.save!
    set_account(mailbox.smtp_mailbox)
    assert_equal mailbox.smtp_mailbox.account_id, mailbox.account_id
  ensure
    mailbox.destroy
  end

  def test_encrypt_refresh_token
    mailbox = create_email_config(
      support_email: 'test@test4.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.save!
    encrypt_refresh_token(mailbox.smtp_mailbox)
    assert_not_equal mailbox.smtp_mailbox.refresh_token, 'refreshtoken'
  ensure
    mailbox.destroy
  end

  def test_encrypt_password
    mailbox = create_email_config(
      support_email: 'test@test5.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.save!
    encrypt_password(mailbox.smtp_mailbox)
    assert_not_equal mailbox.smtp_mailbox.password, 'password'
  ensure
    mailbox.destroy
  end

  def test_nullify_error_type_on_reauth
    mailbox = create_email_config(
      support_email: 'test@test6.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.smtp_mailbox.error_type = 401
    mailbox.smtp_mailbox.password = '123'
    mailbox.smtp_mailbox.refresh_token = '456'
    mailbox.save!
    nullify_error_type_on_reauth(mailbox.smtp_mailbox)
    assert_not_equal mailbox.smtp_mailbox.error_type, 401
  ensure
    mailbox.destroy
  end

  def test_changed_credentials
    mailbox = create_email_config(
      support_email: 'test@test7.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2' 
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2' 
      }
    )
    mailbox.active = true
    mailbox.smtp_mailbox.password = '123'
    mailbox.save!
    credentials_changed = changed_credentials?(mailbox.smtp_mailbox)
    assert_equal credentials_changed, true
  ensure
    mailbox.destroy
  end
end
