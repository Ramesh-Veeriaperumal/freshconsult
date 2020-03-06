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
      @account.save!
    end

    def test_with_freshconnect_disabled?
      @account.launch(:freshid_org_v2)
      @account.revoke_feature(:freshconnect)
      put :onboard, construct_params(version: 'private')
      assert_response 403
      match_json('code' => 'require_feature',
                 'message' => 'The freshconnect feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
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
  end
end
