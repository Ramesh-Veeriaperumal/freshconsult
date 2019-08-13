require_relative '../../test_helper'
require 'webmock/minitest'
module Ember
  class FlowsControllerTest < ActionController::TestCase
    def enabling_botflow_feature
      @account.add_feature(:botflow)
    end

    def disabling_botflow_feature
      @account.revoke_feature(:botflow)
    end

    def test_freshbot_proxy_success_response
      @account.reload
      enabling_botflow_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:flowserv][:host]}.*?$}).to_return(status: 200)
      get :freshbot_proxy, controller_params
      assert_response 200
    ensure
      disabling_botflow_feature
    end

    def test_freshbot_proxy_fail_response
      @account.reload
      enabling_botflow_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:flowserv][:host]}.*?$}).to_return(status: 500)
      get :freshbot_proxy, controller_params
      assert_response 500
    ensure
      disabling_botflow_feature
    end

    def test_system42_proxy_success_response
      @account.reload
      enabling_botflow_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:system42][:host]}.*?$}).to_return(status: 200)
      get :system42_proxy, controller_params
      assert_response 200
    ensure
      disabling_botflow_feature
    end

    def test_system42_proxy_fail_response
      @account.reload
      enabling_botflow_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:system42][:host]}.*?$}).to_return(status: 500)
      get :system42_proxy, controller_params
      assert_response 500
    ensure
      disabling_botflow_feature
    end
  end
end
