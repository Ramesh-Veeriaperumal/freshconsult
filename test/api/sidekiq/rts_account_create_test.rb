require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!

class RTSAccountCreateTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first || create_new_account
    @account.make_current
  end

  def teardown
    @account.account_additional_settings.additional_settings.delete(:rts_account_id)
    @account.account_additional_settings.secret_keys.delete(:rts_account_secret)
    @account.save
    @account.make_current.reload
  end

  def rts_success_response
    {
      msg: 'Successfully registered [Account: 1]',
      accId: 'WO1JZJV87y',
      appId: 'MlGWDd7X',
      url: '/account/WO1JZJV87V',
      key: 'L5es8_QldiIRibsE2ldeha0C6cEOSWPDwp68l8FWa1c='
    }
  end

  def http_proxy_response
    {
      text: rts_success_response.to_json,
      status: 200
    }
  end

  def test_rts_account_create_success
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(http_proxy_response)
    AccountCreation::RTSAccountCreate.new.perform
    @account.make_current.reload
    rts_account_id = @account.account_additional_settings.additional_settings[:rts_account_id]
    encrypted_secret = @account.account_additional_settings.secret_keys[:rts_account_secret]
    assert_equal rts_success_response[:accId], rts_account_id
    assert_equal EncryptorDecryptor.new(RTSConfig['db_cipher_key']).encrypt(rts_success_response[:key]), encrypted_secret
  end

  def test_rts_account_create_with_acc_nil
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(http_proxy_response)
    Account.stubs(:current).returns(nil)
    assert_raise(RuntimeError) { AccountCreation::RTSAccountCreate.new.perform }
    Account.unstub(:current)
  end

  def test_rts_account_create_throws_exception
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).raises(StandardError.new('Error'))
    assert_raise(StandardError) { AccountCreation::RTSAccountCreate.new.perform }
    rts_account_id = @account.account_additional_settings.additional_settings[:rts_account_id]
    encrypted_secret = @account.account_additional_settings.secret_keys[:rts_account_secret]
    assert_nil rts_account_id
    assert_nil encrypted_secret
  end

  def test_rts_account_create_api_call_fails
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 400)
    AccountCreation::RTSAccountCreate.new.perform
    rts_account_id = @account.account_additional_settings.additional_settings[:rts_account_id]
    encrypted_secret = @account.account_additional_settings.secret_keys[:rts_account_secret]
    assert_nil rts_account_id
    assert_nil encrypted_secret
  end
end
