# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'lib', 'helpers', 'oauth_authenticator_test_helper.rb')

class OutlookAuthenticatorTest < ActiveSupport::TestCase
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
    outlook_authenticator = Auth::OutlookAuthenticator.new(options('outlook', true, 'test@1234'))
    obj = outlook_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    assert_includes(obj.redirect_url, 'reference_key')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_new_failed_oauth
    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj('new'))
    outlook_authenticator = Auth::OutlookAuthenticator.new(options('outlook', true, 'test@1234'))
    obj = outlook_authenticator.after_authenticate(params('new'))
    assert_includes(obj.redirect_url, 'new')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_success_oauth
    options = options('outlook', false, 'test@1234')
    omniauth = omniauth_for_outlook
    options[:omniauth] = OpenStruct.new(omniauth)
    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj('edit'))
    outlook_authenticator = Auth::OutlookAuthenticator.new(options)
    obj = outlook_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_no_redis
    outlook_authenticator = Auth::OutlookAuthenticator.new(options('outlook', false))
    obj = outlook_authenticator.after_authenticate(params('edit'))
    assert_includes(obj.redirect_url, 'edit')
    refute_includes(obj.redirect_url, 'reference_key')
  end
end
