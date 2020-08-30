require_relative '../../test_helper'
require 'webmock/minitest'
module Ember
  class FreddyControllerTest < ActionController::TestCase
    include FreddyHelper
    include OmniChannelsTestHelper
    include ApiAccountHelper

    CHARGEBEE_SUBSCRIPTION_BASE_URL = 'https://freshpo-test.chargebee.com/api/v1/subscriptions'.freeze
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
      plan = SubscriptionPlan.where(name: SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_19]).first
      @account.subscription.state = 'trial'
      @account.subscription.plan = plan
      @account.subscription.save
      url = "#{CHARGEBEE_SUBSCRIPTION_BASE_URL}/#{@account.id}"
      @account.conversion_metric = ConversionMetric.new(account_id: @account.id, landing_url: 'http://freshdesk.com/signup', first_referrer: 'http://freshdesk.com/signup', first_landing_url: 'http://freshdesk.com/signup', country: 'INDIA')
      @account.conversion_metric.save!
      forest_omni_plan = SubscriptionPlan.where(name: SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_omni_jan_20])
      SubscriptionPlan.stubs(:current).returns(forest_omni_plan)
      SubscriptionPlan.any_instance.stubs(:unlimited_multi_product?).returns(false)
      stub_request(:get, url).to_return(status: 200, body: chargebee_subscripiton_reponse.to_json, headers: {})
      stub_request(:post, url).to_return(status: 200, body: chargebee_subscripiton_reponse.to_json, headers: {})
      stub_request(:post, %r{^#{AlohaConfig[:host]}v2/signup/freshchat}).to_return(body: freshchat_aloha_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
      org_domain = Faker::Internet.domain_name
      Account.any_instance.stubs(:organisation).returns(Organisation.new(organisation_id: Faker::Number.number(5), domain: org_domain))
      Freshid::V2::Models::Organisation.stubs(:find_by_domain).returns(id: Faker::Number.number(5))
      user = @account.technicians.first
      org_admin_response = org_admin_users_response
      org_admin_response[:users][0][:email] = user.email
      Freshid::V2::Models::User.stubs(:account_users).returns(org_admin_response)
      Freshid::V2::Models::User.stubs(:find_by_email).returns(Freshid::V2::Models::User.new(id: Faker::Number.number(5), first_name: Faker::Name.first_name, email: user.email))
      Freshid::V2::Models::Organisation.stubs(:join_token).returns(Faker::Lorem.word)
      post :bulk_create_bot, controller_params
      assert_response 200
    ensure
      Freshid::V2::Models::Organisation.unstub(:find_by_domain)
      Freshid::V2::Models::User.unstub(:account_users)
      Freshid::V2::Models::User.unstub(:find_by_email)
      Freshid::V2::Models::Organisation.unstub(:join_token)
      Account.any_instance.unstub(:organisation)
      SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
      SubscriptionPlan.unstub(:current)
      @account.freshchat_account.destroy
      @account.conversion_metric.destroy
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
