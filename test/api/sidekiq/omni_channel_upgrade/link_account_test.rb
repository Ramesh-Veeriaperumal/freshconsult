# frozen_string_literal: true

require_relative '../../unit_test_helper'
['account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }
require 'sidekiq/testing'
require 'webmock/minitest'

Sidekiq::Testing.fake!

class OmniChannelUpgrade::LinkAccountTest < ActionView::TestCase
  include OmniChannel::Constants
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    super
    create_test_account
  end

  def test_link_account_worker_should_fail_when_freshcaller_move_to_bundle_fails
    Freshcaller::Account.stubs(:create).returns(true)
    freshcaller_account = Freshcaller::Account.new(account_id: @account.id, domain: 'testbundlefreshcaller.freshfonehello.com')
    Account.any_instance.stubs(:freshcaller_account).returns(freshcaller_account)
    stub_request(:put, 'https://testbundlefreshcaller.freshfonehello.com/link_account').to_return(status: 503, body: {}.to_json, headers: {})
    assert_raises StandardError do
      OmniChannelUpgrade::LinkAccount.new.perform(product_name: FRESHCALLER, params: {})
    end
  ensure
    Freshcaller::Account.unstub(:create)
    Account.any_instance.unstub(:freshcaller_account)
  end

  def test_link_account_worker_should_fail_when_freshchat_move_to_bundle_fails
    fc_account_object = Freshchat::Account.new(app_id: 'app-bundle-id')
    Account.any_instance.stubs(:freshchat_account).returns(fc_account_object)
    move_to_bundle_response = {}
    move_to_bundle_response.stubs(:body).returns({})
    move_to_bundle_response.stubs(:code).returns(503)
    HTTParty.stubs(:put).returns(move_to_bundle_response)
    assert_raises StandardError do
      OmniChannelUpgrade::LinkAccount.new.perform(product_name: FRESHCHAT, params: {})
    end
  ensure
    Account.any_instance.unstub(:freshchat_account)
    HTTParty.unstub(:put)
  end

  def test_link_account_worker_executes_freshcaller_move_to_bundle_without_error
    Freshcaller::Account.stubs(:create).returns(true)
    freshcaller_account = Freshcaller::Account.new(account_id: @account.id, domain: 'testbundlefreshcaller.freshfonehello.com')
    Account.any_instance.stubs(:freshcaller_account).returns(freshcaller_account)
    stub_request(:put, 'https://testbundlefreshcaller.freshfonehello.com/link_account').to_return(status: 200, body: {}.to_json, headers: {})
    assert_nothing_raised do
      OmniChannelUpgrade::LinkAccount.new.perform(product_name: FRESHCALLER, params: {})
    end
  ensure
    Freshcaller::Account.unstub(:create)
    Account.any_instance.unstub(:freshcaller_account)
  end

  def test_link_account_worker_executes_freshchat_move_to_bundle_without_error
    fc_account_object = Freshchat::Account.new(app_id: 'app-bundle-id')
    Account.any_instance.stubs(:freshchat_account).returns(fc_account_object)
    move_to_bundle_response = {}
    move_to_bundle_response.stubs(:body).returns({})
    move_to_bundle_response.stubs(:code).returns(200)
    HTTParty.stubs(:put).returns(move_to_bundle_response)
    assert_nothing_raised do
      OmniChannelUpgrade::LinkAccount.new.perform(product_name: FRESHCHAT, params: {})
    end
  ensure
    Account.any_instance.unstub(:freshchat_account)
    HTTParty.unstub(:put)
  end
end
