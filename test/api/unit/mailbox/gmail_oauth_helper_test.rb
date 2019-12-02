require_relative '../../unit_test_helper'
require_relative '../../../api/helpers/email_mailbox_test_helper.rb'
['gmail_oauth_helper.rb'].each { |file| require Rails.root.join("lib/email/mailbox/#{file}") }

class Mailbox::GmailOauthHelperTest < ActiveSupport::TestCase
  include EmailMailboxTestHelper
  include Email::Mailbox::GmailOauthHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_refreshing_invalid_access_token_success
    mailbox = create_email_config(
      support_email: 'testoauth@fdtest.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true
      }
    )
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:decrypt_refresh_token).returns('refreshtoken')
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:get_oauth2_access_token).returns(
      OAuth2::AccessToken.new(
        OAuth2::Client.new(
          "token_aaa",
          "secret_aaa"
          ),
        "token_abc"
      )
    )
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:redis_key_exists?).returns(true)
    refresh_access_token(mailbox.smtp_mailbox)
    assert_equal access_token_expired?(mailbox.account_id, mailbox.smtp_mailbox.id), false
  ensure
    Mailbox::GmailOauthHelperTest.unstub(:decrypt_refresh_token)
    Mailbox::GmailOauthHelperTest.unstub(:get_oauth2_access_token)
    Mailbox::GmailOauthHelperTest.unstub(:redis_key_exists?)
    $redis_others.perform_redis_op(
      'del',
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      )
    )
    mailbox.destroy
  end

  def test_refreshing_invalid_access_token_failure
    mailbox = create_email_config(
      support_email: 'testoauth@fdtest.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true
      }
    )
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:decrypt_refresh_token).returns('refreshtoken')
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:get_oauth2_access_token).raises(
      OAuth2::Error.new(
        OAuth2::Response.new(
          Faraday::Response.new()
        )
      )
    )
    refresh_access_token(mailbox.smtp_mailbox)
    assert_equal mailbox.smtp_mailbox.error_type, 401
  ensure
    Mailbox::GmailOauthHelperTest.unstub(:get_oauth2_access_token)
    $redis_others.perform_redis_op(
      'del',
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      )
    )
    mailbox.destroy
  end

  def test_failed_mailbox
    mailbox = create_email_config(
      support_email: 'testoauth@fdtest.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true
      }
    )
    mailbox.active = true
    mailbox.smtp_mailbox.error_type = 401
    mailbox.save!
    failed_mailbox = failed_mailbox?(mailbox.reply_email)
    assert_equal failed_mailbox, true
  ensure
    mailbox.destroy
  end

  def test_access_token_expired
    mailbox = create_email_config(
      support_email: 'testoauth@fdtest.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true
      }
    )
    mailbox.smtp_mailbox.error_type = 401
    mailbox.save!
    set_valid_access_token_key(Account.current.id, mailbox.id)
    Mailbox::GmailOauthHelperTest.any_instance.stubs(:redis_key_exists?).returns(true)
    expired = access_token_expired?(Account.current.id, mailbox.id)
    assert_equal expired, false
  ensure
    Mailbox::GmailOauthHelperTest.unstub(:redis_key_exists?)
    $redis_others.perform_redis_op(
      'del',
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      )
    )
    mailbox.destroy   
  end
end
