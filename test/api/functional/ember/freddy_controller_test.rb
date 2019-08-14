require_relative '../../test_helper'
require 'webmock/minitest'
module Ember
  class FreddyControllerTest < ActionController::TestCase
    include FreddyHelper
    def enable_autofaq_feature
      @account.add_feature(:autofaq)
    end

    def disable_autofaq_feature
      @account.revoke_feature(:autofaq)
    end

    def test_success_response
      @account.reload
      enable_autofaq_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:system42][:host]}.*?$}).to_return(status: 200)
      get :execute, controller_params
      assert_response 200
    ensure
      disable_autofaq_feature
    end

    def test_fail_response
      @account.reload
      enable_autofaq_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:system42][:host]}.*?$}).to_return(status: 500)
      get :execute, controller_params
      assert_response 500
    ensure
      disable_autofaq_feature
    end

    def test_bulk_create_success_response
      @account.reload
      enable_autofaq_feature
      stub_request(:post, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
      get :bulk_create_bot, controller_params
      assert_response 200
    ensure
      disable_autofaq_feature
    end

    def test_bulk_create_fail_response
      @account.reload
      enable_autofaq_feature
      stub_request(:post, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 500)
      get :bulk_create_bot, controller_params
      assert_response 500
    ensure
      disable_autofaq_feature
    end
  end
end
