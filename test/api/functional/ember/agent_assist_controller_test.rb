require_relative '../../test_helper'
require 'webmock/minitest'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
module Ember
  class AgentAssistControllerTest < ActionController::TestCase
    include AgentAssistHelper
    include AccountTestHelper
    LIST_BOTS_PATH = '/rest/api/v2/bots/agentassist/'.freeze
    def setup
      super
      before_all
    end

    def before_all
      @user = create_test_account
      @account = @user.account.make_current
      @account.account_additional_settings.additional_settings.delete(:agent_assist_config)
      @account.set_feature(:agent_assist_lite)
      @account.save!
    end

    def stub_plan_url(feature)
      stub_request(:put, "#{::AgentAssist::Util::PLAN_UPDATE_URL}?_plan=#{feature}")
        .with(headers: {
                'External-Client-Id' => @account.id.to_s,
                'Product-Id' => FreddySkillsConfig[:agent_assist][:product_id],
                'fbots-service' => 'bot-admin'
              })
        .to_return(status: 200, body: '', headers: {})
    end

    def test_with_freshconnect_disabled?
      @account.launch(:freshid_org_v2)
      @account.revoke_feature(:freshconnect)
      put :onboard, construct_params(version: 'private')
      assert_response 403
      match_json('code' => 'require_feature',
                 'message' => 'The Freshconnect,Agent Assist Lite feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
    ensure
      @account.rollback(:freshid_org_v2)
      @account.add_feature(:freshconnect)
    end

    def test_with_freshid_org_v2_disabled?
      put :onboard, construct_params(version: 'private')
      assert_response 403
      match_json('code' => 'require_feature',
                 'message' => 'The freshid_org_v2 feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
    end

    def test_with_agent_assist_lite_disabled?
      @account.revoke_feature(:agent_assist_lite)
      put :onboard, construct_params(version: 'private')
      assert_response 403
      match_json('code' => 'require_feature',
                 'message' => 'The Freshconnect,Agent Assist Lite feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
    ensure
      @account.add_feature(:agent_assist_lite)
    end

    def test_without_manage_bot_privilege?
      User.any_instance.stubs(:privilege?).with(:manage_bots).returns(false)
      put :onboard, construct_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_success_response_onboard
      @account.launch(:freshid_org_v2)
      stub_request(:post, %r{^#{FreddySkillsConfig[:agent_assist][:onboard_url]}.*?$}).to_return(body: onboard_agent_assist_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      put :onboard, construct_params(version: 'private')
      assert_response 200
    ensure
      @account.rollback(:freshid_org_v2)
    end

    def test_onboard_success_response
      domain = 'agentassistc5abcba4719472cc67d2b582b35da746.stagfreshbots.co'
      @account.account_additional_settings.update_agent_assist_config!(domain: domain)
      get :show, construct_params(version: 'private')
      assert_response 200
      assert_equal domain, JSON.parse(response.body)['domain']
    end

    def test_onboard_empty_response
      domain = 'agentassistc5abcba4719472cc67d2b582b35da746.stagfreshbots.co'
      @account.account_additional_settings.update_agent_assist_config!({})
      get :show, construct_params(version: 'private')
      assert_response 200
      assert_equal response.body, '{}'
    end

    def test_agent_assist_bots_success_response
      domain = 'agentassistc5abcba4719472cc67d2b582b35da746.stagfreshbots.co'
      @account.account_additional_settings.update_agent_assist_config!(domain: domain)
      stub_request(:get, %r{^https://#{domain}#{LIST_BOTS_PATH}.*?$}).to_return(body: agent_assist_bots_response, headers: { 'Content-Type' => 'application/json' }, status: 200)
      get :bots, controller_params
      assert_response 200
    end

    def test_agent_assist_bots_without_manage_tickets_privilege
      domain = 'agentassistc5abcba4719472cc67d2b582b35da746.stagfreshbots.co'
      @account.account_additional_settings.update_agent_assist_config!(domain: domain)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :bots, controller_params
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_agent_assist_lite_forest_jan_20
      sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_20])
      SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
      create_sample_account('forestjan20agentassistlite', 'forestjan20agentassistlite@freshdesk.test')
      assert @account.has_features?(:agent_assist_lite)
    ensure
      SubscriptionPlan.unstub(:find_by_name)
      @account.destroy
    end

    def test_agent_assist_ultimate_add
      create_test_account
      agent_ssist_stub = stub_plan_url(::AgentAssist::Util::AGENT_ASSIST_ULTIMATE)
      clean_up = SAAS::AccountDataCleanup.new(@account, ['agent_assist_ultimate'], 'add')
      assert_equal clean_up.handle_agent_assist_ultimate_add_data.response.code, '200'
    ensure
      remove_request_stub(agent_ssist_stub)
    end

    def test_agent_assist_ultimate_drop
      create_test_account
      agent_ssist_stub = stub_plan_url(::AgentAssist::Util::AGENT_ASSIST_LITE)
      clean_up = SAAS::AccountDataCleanup.new(@account, ['agent_assist_ultimate'], 'drop')
      assert_equal clean_up.handle_agent_assist_ultimate_drop_data.response.code, '200'
    ensure
      remove_request_stub(agent_ssist_stub)
    end

    def test_agent_assist_lite_drop
      create_test_account
      agent_ssist_stub = stub_request(:put, ::AgentAssist::Util::DISABLE_FRESHBOTS_URL).to_return(status: 200)
      clean_up = SAAS::AccountDataCleanup.new(@account, ['agent_assist_lite'], 'drop')
      assert_equal clean_up.handle_agent_assist_lite_drop_data.response.code, '200'
    ensure
      remove_request_stub(agent_ssist_stub)
    end
  end
end
