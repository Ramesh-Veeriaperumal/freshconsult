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

    def test_bulk_create_with_freshchat_success_response
      @account.reload
      enable_autofaq_feature
      FreddyController.any_instance.stubs(:signup_body).returns('{}')
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(name: 'Estate Jan 19'))
      stub_request(:post, %r{^#{AlohaConfig[:host]}v2/signup/freshchat}).to_return(body: freshchat_aloha_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
      post :bulk_create_bot, controller_params
      assert_response 200
    ensure
      @account.freshchat_account.destroy
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      disable_autofaq_feature
    end

    def test_bulk_create_without_freshchat_success_response
      @account.reload
      enable_autofaq_feature
      Freshchat::Account.create(app_id: 'test', portal_widget_enabled: false, token: '', enabled: true)
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(name: 'Forest Omni Jan 20'))
      stub_request(:put, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
      post :bulk_create_bot, controller_params
      assert_response 200
    ensure
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      disable_autofaq_feature
    end

    def test_bulk_create_fail_response
      @account.reload
      enable_autofaq_feature
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(name: 'Forest Omni Jan 20'))
      FreddyController.any_instance.stubs(:signup_body).returns('{}')
      stub_request(:post, %r{^#{AlohaConfig[:host]}v2/signup/freshchat}).to_return(body: freshchat_aloha_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 500)
      post :bulk_create_bot, controller_params
      assert_response 500
    ensure
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      @account.freshchat_account.destroy
      disable_autofaq_feature
    end

    def test_bulk_create_freshchat_failure
      @account.reload
      enable_autofaq_feature
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(name: 'Forest Omni Jan 20'))
      FreddyController.any_instance.stubs(:signup_body).returns('{}')
      stub_request(:post, %r{^#{AlohaConfig[:host]}v2/signup/freshchat}).to_return(status: [500, 'Internal Server Error'])
      post :bulk_create_bot, controller_params
      assert_response 500
    ensure
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      disable_autofaq_feature
    end

    def test_bulk_create_with_existing_freshchat_account
      @account.reload
      enable_autofaq_feature
      Freshchat::Account.create(app_id: 'test', portal_widget_enabled: false, token: '', enabled: true)
      FreddyController.any_instance.stubs(:signup_body).returns('{}')
      Subscription.any_instance.stubs(:subscription_plan_from_cache).returns(SubscriptionPlan.new(name: 'Forest Omni Jan 20'))
      stub_request(:post, %r{^#{AlohaConfig[:host]}v2/signup/freshchat}).to_return(status: [500, 'Internal Server Error'])
      stub_request(:put, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
      post :bulk_create_bot, controller_params
      assert_response 200
    ensure
      Subscription.any_instance.unstub(:subscription_plan_from_cache)
      @account.freshchat_account.destroy
      disable_autofaq_feature
    end
  end
end
