# frozen_string_literal: true

require_relative '../../unit_test_helper'
require_relative '../../../api/helpers/email_mailbox_test_helper.rb'
['oauth2_helper.rb'].each { |file| require Rails.root.join("lib/email/mailbox/#{file}") }

class Mailbox::Oauth2HelperTest < ActiveSupport::TestCase
  include EmailMailboxTestHelper
  include Email::Mailbox::Oauth2Helper

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
        with_refresh_token: true,
        with_access_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      }
    )
    Mailbox::Oauth2HelperTest.any_instance.stubs(:get_oauth2_access_token).returns(
      OAuth2::AccessToken.new(
        OAuth2::Client.new(
          'token_aaa',
          'secret_aaa'
        ),
        'token_abc'
      )
    )
    refresh_access_token(mailbox.smtp_mailbox)
    mailbox.smtp_mailbox.reload
    assert_equal mailbox.smtp_mailbox.access_token, 'token_abc'
  ensure
    Mailbox::Oauth2HelperTest.unstub(:get_oauth2_access_token)
    mailbox.destroy
  end

  def test_refreshing_invalid_access_token_failure
    mailbox = create_email_config(
      support_email: 'testoauth@fdtest.com',
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
    Mailbox::Oauth2HelperTest.any_instance.stubs(:get_oauth2_access_token).raises(
      OAuth2::Error.new(
        OAuth2::Response.new(
          Faraday::Response.new
        )
      )
    )
    $redis_others.perform_redis_op(
      'set',
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox.smtp_mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      ),
      true,
      ex: Email::Mailbox::Constants::ACCESS_TOKEN_EXPIRY
    )
    refresh_access_token(mailbox.smtp_mailbox)
    assert_equal mailbox.smtp_mailbox.error_type, 401
    assert_equal access_token_expired?(mailbox.smtp_mailbox), true
  ensure
    Mailbox::Oauth2HelperTest.unstub(:get_oauth2_access_token)
    $redis_others.perform_redis_op(
      'del',
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox.smtp_mailbox)],
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
        with_refresh_token: true,
        with_access_token: true
      },
      smtp_mailbox_attributes: {
        smtp_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      }
    )
    mailbox.save!
    $redis_others.perform_redis_op(
      'set',
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox.smtp_mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      ),
      true,
      ex: Email::Mailbox::Constants::ACCESS_TOKEN_EXPIRY
    )
    expired = access_token_expired?(mailbox.smtp_mailbox)
    assert_equal expired, false
  ensure
    $redis_others.perform_redis_op(
      'del',
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox.smtp_mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.smtp_mailbox.id
      )
    )
    mailbox.destroy
  end
end
