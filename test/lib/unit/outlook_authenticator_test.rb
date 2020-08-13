# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class OutlookAuthenticatorTest < ActiveSupport::TestCase
  include UsersHelper
  include AccountTestHelper

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
    options = {
      app: 'outlook',
      user_id: 1,
      r_key: 'test@1234',
      failed: true,
      origin_account: @account
    }
    params = {
      type: 'edit'
    }

    cached_obj = {
      'type' => 'edit',
      'r_key' => 'test@1234'
    }

    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj)
    outlook_authenticator = Auth::OutlookAuthenticator.new(options)
    obj = outlook_authenticator.after_authenticate(params)
    assert_includes(obj.redirect_url, 'edit')
    refute_includes(obj.redirect_url, 'reference_key')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_new_failed_oauth
    options = {
      app: 'outlook',
      user_id: 1,
      r_key: 'test@1234',
      failed: true,
      origin_account: @account
    }
    params = {
      type: 'new'
    }

    cached_obj = {
      'type' => 'new',
      'r_key' => 'test@1234'
    }

    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj)
    outlook_authenticator = Auth::OutlookAuthenticator.new(options)
    obj = outlook_authenticator.after_authenticate(params)
    assert_includes(obj.redirect_url, 'new')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_success_oauth
    options = {
      app: 'outlook',
      user_id: 1,
      r_key: 'test@1234',
      failed: false,
      origin_account: @account
    }

    omniauth = {
      credentials: OpenStruct.new(
        refresh_token: 'testrefreshtoken',
        token: 'testtoken'
      ),
      'extra' => {
        'raw_info' => {
          'mail' => 'testemail'
        }
      }
    }

    options[:omniauth] = OpenStruct.new(omniauth)
    params = {
      type: 'edit'
    }

    cached_obj = {
      'type' => 'edit',
      'r_key' => 'test@1234'
    }

    Email::Mailbox::OauthRedis.any_instance.stubs(:fetch_hash).returns(cached_obj)
    outlook_authenticator = Auth::OutlookAuthenticator.new(options)
    obj = outlook_authenticator.after_authenticate(params)
    assert_includes(obj.redirect_url, 'edit')
    assert_includes(obj.redirect_url, 'reference_key=test@1234')
  ensure
    Email::Mailbox::OauthRedis.any_instance.unstub(:fetch_hash)
  end

  def test_after_authenticate_edit_no_redis
    options = {
      app: 'outlook',
      user_id: 1,
      failed: false,
      origin_account: @account
    }
    params = {
      type: 'edit'
    }
    outlook_authenticator = Auth::OutlookAuthenticator.new(options)
    obj = outlook_authenticator.after_authenticate(params)
    assert_includes(obj.redirect_url, 'edit')
    refute_includes(obj.redirect_url, 'reference_key')
  end
end
