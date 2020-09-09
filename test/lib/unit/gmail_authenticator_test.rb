require_relative '../test_helper'
require 'minitest/spec'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'lib', 'helpers', 'oauth_authenticator_test_helper.rb')

class GmailAuthenticatorTest < ActiveSupport::TestCase
  include UsersHelper
  include AccountTestHelper
  include OauthAuthenticatorTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def teardown
    super
  end

  def test_after_authenticate_edit_failed_oauth
    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj('edit'))
    gmail_authenticator = Auth::GmailAuthenticator.new(options('gmail', true, 'test@1234'))
    obj = gmail_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    assert_includes(obj.redirect_url, 'reference_key')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_new_failed_oauth
    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj('new'))
    gmail_authenticator = Auth::GmailAuthenticator.new(options('gmail', true, 'test@1234'))
    obj = gmail_authenticator.after_authenticate(params('new'))
    assert_includes(obj.redirect_url, 'new')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_success_oauth
    options = options('gmail', false, 'test@1234')
    options[:omniauth] = OpenStruct.new(omniauth_for_gmail)
    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj('edit'))
    gmail_authenticator = Auth::GmailAuthenticator.new(options)
    obj = gmail_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_no_redis
    gmail_authenticator = Auth::GmailAuthenticator.new(options('gmail', false))
    obj = gmail_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    refute_includes(obj.redirect_url, 'reference_key')
  end
end
