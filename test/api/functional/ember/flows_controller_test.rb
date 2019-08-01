require_relative '../../test_helper'
require 'webmock/minitest'
module Ember
  class FlowsControllerTest < ActionController::TestCase
    def enabling_autofaq_feature
      @account.add_feature(:botflow)
    end

    def disabling_autofaq_feature
      @account.revoke_feature(:botflow)
    end

    def test_success_response
      @account.reload
      enabling_autofaq_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:flowserv][:host]}.*?$}).to_return(status: 200)
      get :execute, controller_params
      assert_response 200
    ensure
      disabling_autofaq_feature
    end

    def test_fail_response
      @account.reload
      enabling_autofaq_feature
      stub_request(:get, %r{^#{FreddySkillsConfig[:flowserv][:host]}.*?$}).to_return(status: 500)
      get :execute, controller_params
      assert_response 500
    ensure
      disabling_autofaq_feature
    end
  end
end
