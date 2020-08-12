# frozen_string_literal: true

require_relative '../test_helper'
require 'minitest/spec'

class OutlookAuthenticatorTest < ActiveSupport::TestCase
  def test_after_authenticate_edit_failed_oauth
    options = {
      app: 'outlook',
      user_id: 1,
      r_key: 'test@1234',
      failed: true,
      origin_account: Account.current
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
      origin_account: Account.current
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
      origin_account: Account.current
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
      origin_account: Account.current
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
