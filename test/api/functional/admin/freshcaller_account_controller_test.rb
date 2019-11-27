require_relative '../../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require 'webmock/minitest'
WebMock.allow_net_connect!

module Admin
  class FreshcallerAccountControllerTest < ActionController::TestCase
    include ::Freshcaller::TestHelper
    include ::Freshcaller::Endpoints

    def setup
      super
      Sidekiq::Worker.clear_all
      launch_freshcaller_features
    end

    def teardown
      revoke_freshcaller_features
    end

    def launch_freshcaller_features
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
    end

    def revoke_freshcaller_features
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def wrap_cname(params)
      { freshcaller_account: params }
    end

    def stub_freshcaller_request(code: 200, body: {}, message: 'OK')
      ::Freshcaller::Account.any_instance.stubs(:domain).returns('test.freshcaller.com')
      HTTParty::Response.any_instance.stubs(:body).returns(body.to_json)
      HTTParty::Response.any_instance.stubs(:message).returns(message)
      HTTParty::Response.any_instance.stubs(:code).returns(code)
    end

    def unstub_freshcaller_request
      HTTParty::Request.any_instance.unstub(:perform)
      HTTParty::Response.any_instance.unstub(:message)
      HTTParty::Response.any_instance.unstub(:code)
      ::Freshcaller::Account.any_instance.unstub(:domain)
    end

    def test_show_with_no_feature_check
      revoke_freshcaller_features
      get :show, controller_params(version: 'private')
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
      match_json(code: 'require_feature', message:
            'The Freshcaller,Freshcaller Admin New Ui feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
    ensure
      launch_freshcaller_features
    end

    def test_show_with_freshcaller_account_associated_and_enabled_state
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    end

    def test_show_with_freshcaller_account_disabled_state
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      freshcaller_account.enabled = false
      freshcaller_account.save!
      freshcaller_account.reload
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    end

    def test_show_with_feature_and_no_freshcaller_account_associated
      delete_freshcaller_account if Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 204
    end

    def test_freshcaller_destroy
      current_account = Account.current
      create_freshcaller_account unless Account.current.freshcaller_account
      create_freshcaller_enabled_agent
      freshcaller_account = Account.current.freshcaller_account
      stub_freshcaller_request
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
    end

    def test_freshcaller_destroy_without_account
      Account.current.freshcaller_account.destroy unless Account.current.freshcaller_account.nil?
      Sidekiq::Testing.inline! do
        delete :destroy, construct_params({})
      end
      assert_response 400
    end

    def test_destroy_with_freshcaller_throwing_unprocessable_entity
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request(code: 422)
      freshcaller_account = Account.current.freshcaller_account
      delete :destroy, construct_params(id: freshcaller_account.id)
      assert_response 400
      match_json(request_error_pattern(:fc_unprocessable_entity))
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
    end

    def test_freshcaller_enable
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request
      put :enable, construct_params({})
      assert_response 204
      assert_equal true, Account.current.freshcaller_account.enabled
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
    end

    def test_freshcaller_enable_with_freshcaller_throwing_unprocessable_entity
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request(code: 422)
      put :enable, construct_params({})
      assert_response 400
      match_json(request_error_pattern(:fc_unprocessable_entity))
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
    end

    def test_freshcaller_disable
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request
      put :disable, construct_params({})
      assert_response 204
      assert_equal false, Account.current.freshcaller_account.enabled
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
    end

    def test_freshcaller_disable_with_freshcaller_throwing_unprocessable_entity
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_freshcaller_request(code: 422)
      put :disable, construct_params({})
      assert_response 400
      match_json(request_error_pattern(:fc_unprocessable_entity))
    ensure
      delete_freshcaller_account
      unstub_freshcaller_request
    end

    def test_no_integration
      delete_freshcaller_account unless Account.current.freshcaller_account.nil?
      put :enable, construct_params({})
      assert_response 400
      match_json([bad_request_error_pattern('freshcaller_account', :fc_account_absent)])
    end

    def test_link_with_feature_and_correct_user_email
      agent = add_test_agent(@account)
      stub_link_account_success(agent.email)
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 200
      Account.current.reload
      match_json(Account.current.freshcaller_account.as_api_response(:api))
    ensure
      delete_freshcaller_account
      remove_stubs
    end

    def test_link_wrong_domain
      agent = add_test_agent(@account)
      stub_link_account_invalid_domain
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 400
      match_json(request_error_pattern(:fc_invalid_domain_name))
    ensure
      remove_stubs
    end

    def test_link_wrong_freshcaller_email
      agent = add_test_agent(@account)
      stub_link_account_access_restricted
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 403
      match_json(request_error_pattern(:fc_access_restricted))
    ensure
      remove_stubs
    end

    def test_link_wrong_password
      agent = add_test_agent(@account)
      stub_link_account_password_incorrect
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 400
      match_json(request_error_pattern(:fc_password_incorrect))
    ensure
      remove_stubs
    end

    def test_link_with_freshcaller_throwing_access_denied
      agent = add_test_agent(@account)
      stub_link_account_access_denied
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 403
      match_json(request_error_pattern(:fc_access_denied))
    ensure
      remove_stubs
    end

    def test_link_with_freshcaller_throwing_unprocessable_entity
      agent = add_test_agent(@account)
      stub_link_account_unprocessible_entity
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 400
      match_json(request_error_pattern(:fc_unprocessable_entity))
    ensure
      remove_stubs
    end
  end
end
