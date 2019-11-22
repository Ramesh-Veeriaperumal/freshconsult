require_relative '../../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

module Admin
  class FreshcallerAccountControllerTest < ActionController::TestCase
    include ::Freshcaller::TestHelper

    def setup
      super
      Sidekiq::Worker.clear_all
    end

    def launch_freshcaller_features
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
    end

    def revoke_freshcaller_features
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def stub_freshcaller_request(code)
      ::Freshcaller::Account.any_instance.stubs(:domain).returns('test.freshcaller.com')
      HTTParty::Response.any_instance.stubs(:message).returns('test message')
      HTTParty::Response.any_instance.stubs(:code).returns(code)
    end

    def unstub_freshcaller_request
      HTTParty::Response.any_instance.unstub(:message)
      HTTParty::Response.any_instance.unstub(:code)
      ::Freshcaller::Account.any_instance.unstub(:domain)
    end

    def test_show_with_no_feature_check
      Account.current.rollback :freshcaller_admin_new_ui
      get :show, controller_params(version: 'private')
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
      match_json({code: 'require_feature', message: 
            'The Freshcaller,Freshcaller Admin New Ui feature(s) is/are not supported in your plan. Please upgrade your account to use it.'})
    end

    def test_show_with_freshcaller_account_associated_and_enabled_state
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def test_show_with_freshcaller_account_disabled_state
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      freshcaller_account.enabled = false
      freshcaller_account.save!
      freshcaller_account.reload
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def test_show_with_feature_and_no_freshcaller_account_associated
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      delete_freshcaller_account if Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 204
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def test_freshcaller_destroy
      current_account = Account.current
      launch_freshcaller_features
      create_freshcaller_account unless Account.current.freshcaller_account
      create_freshcaller_enabled_agent
      freshcaller_account = Account.current.freshcaller_account
      stub_freshcaller_request(200)
      Sidekiq::Testing.inline! do
        delete :destroy, construct_params(id: freshcaller_account.id)
      end
      unstub_freshcaller_request
      assert_response 204
      assert_equal @agent.agent.freshcaller_agent, nil, 'Freshcaller Agent not destroyed!'
    ensure
      unstub_freshcaller_request
      current_account.make_current
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      revoke_freshcaller_features
    end

    def test_freshcaller_destroy_without_account
      launch_freshcaller_features
      Account.current.freshcaller_account.destroy unless Account.current.freshcaller_account.nil?
      Sidekiq::Testing.inline! do
        delete :destroy, construct_params({})
      end
      assert_response 400
    ensure
      revoke_freshcaller_features
    end

    def test_freshcaller_enable
      launch_freshcaller_features
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request(200)
      put :enable, construct_params({})
      assert_response 204
      assert_equal true, Account.current.freshcaller_account.enabled
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
      revoke_freshcaller_features
    end

    def test_freshcaller_disable
      launch_freshcaller_features
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request(200)
      put :disable, construct_params({})
      assert_response 204
      assert_equal false, Account.current.freshcaller_account.enabled
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
      revoke_freshcaller_features
    end

    def test_no_integration
      launch_freshcaller_features
      delete_freshcaller_account unless Account.current.freshcaller_account.nil?
      put :enable, construct_params({})
      assert_response 400
      match_json([bad_request_error_pattern('freshcaller_account', :fc_account_absent)])
    ensure
      revoke_freshcaller_features
    end
  end
end
