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

    def freshcaller_account_show_response
      fc_account = Account.current.freshcaller_account.as_api_response(:api)
      fc_account[:agents] = Account.current.freshcaller_agents.where(fc_enabled: true).map { |agent| agent.as_api_response(:api) }
      fc_account
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
      match_json(freshcaller_account_show_response)
    end

    def test_show_with_freshcaller_account_disabled_state
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      freshcaller_account.enabled = false
      freshcaller_account.save!
      freshcaller_account.reload
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account_show_response)
    end

    def test_show_with_freshcaller_agents
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      create_freshcaller_enabled_agent
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account_show_response)
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
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
      match_json(freshcaller_account_show_response)
    ensure
      delete_freshcaller_account
      remove_stubs
    end

    def test_link_for_already_linked
      create_freshcaller_account
      agent = add_test_agent(@account)
      stub_link_account_success(agent.email)
      params_hash = {
        url: 'test.freshcaller.com',
        email: agent.email,
        password: 'test1234'
      }
      post :link, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      assert_response 403
      match_json(request_error_pattern(:account_linked))
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

    def test_create_new_account_success
      agent = add_test_agent(@account)
      stub_create_success
      post :create, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account_show_response)
      assert ::Freshcaller::Agent.find_by_fc_user_id(1234).present?
      assert Account.current.freshcaller_account.present?
      assert Account.current.freshcaller_account.domain, 'test.freshcaller.com'
      assert Account.current.freshcaller_account.freshcaller_account_id, '1234'
    ensure
      delete_freshcaller_account
      remove_stubs
    end

    def test_create_with_already_linked
      create_freshcaller_account
      agent = add_test_agent(@account)
      stub_create_success
      post :create, controller_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:account_linked))
    ensure
      delete_freshcaller_account
      remove_stubs
    end

    def test_create_new_account_spam_email_error
      agent = add_test_agent(@account)
      stub_create_spam_email_error
      post :create, controller_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:fc_spam_email))
    ensure
      remove_stubs
    end

    def test_create_new_account_domain_taken_error
      agent = add_test_agent(@account)
      stub_create_domain_taken_error
      post :create, controller_params(version: 'private')
      assert_response 400
      match_json(request_error_pattern(:fc_domain_taken))
    ensure
      remove_stubs
    end

    def test_create_new_account_unknown_error
      agent = add_test_agent(@account)
      stub_create_unknown_error
      post :create, controller_params(version: 'private')
      assert_response 400
      match_json(request_error_pattern(:unknown_error))
    ensure
      remove_stubs
    end

    def test_update_agents_without_freshcaller_account
      params_hash = { agent_ids: [] }
      put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      match_json([bad_request_error_pattern('freshcaller_account', :fc_account_absent)])
      assert_response 400
    end

    def test_update_agents_wrong_params
      create_freshcaller_account unless Account.current.freshcaller_account
      params_hash = { test: 'hello' }
      put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      match_json([bad_request_error_pattern('test', :invalid_field)])
      assert_response 400
    ensure
      delete_freshcaller_account
    end

    def test_update_agents_with_wrong_agent_ids_type
      create_freshcaller_account unless Account.current.freshcaller_account
      params_hash = { agent_ids: 'test' }
      put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      match_json([bad_request_error_pattern('agent_ids', :datatype_mismatch, prepend_msg: :input_received, expected_data_type: Array, given_data_type: String)])
      assert_response 400
    ensure
      delete_freshcaller_account
    end

    def test_update_agents_to_add_new_agents
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_create_users
      agent1 = add_test_agent(@account).agent
      agent2 = add_test_agent(@account).agent
      params_hash = { agent_ids: [agent1.user.id, agent2.user.id] }
      Sidekiq::Testing.inline! do
        put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      end
      agent1.reload
      agent2.reload
      assert agent1.freshcaller_agent.present?
      assert_equal agent1.freshcaller_agent.fc_user_id, 111
      assert agent1.freshcaller_agent.fc_enabled
      assert agent2.freshcaller_agent.present?
      assert_equal agent2.freshcaller_agent.fc_user_id, 111
      assert agent2.freshcaller_agent.fc_enabled
      assert_response 204
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      remove_stubs
    end

    def test_update_agents_to_remove_new_agents
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_create_users
      agent1 = add_test_agent(@account).agent
      agent1.create_freshcaller_agent(
        fc_enabled: true,
        fc_user_id: 1234
      )
      agent2 = add_test_agent(@account).agent
      agent2.create_freshcaller_agent(
        fc_enabled: true,
        fc_user_id: 5678
      )
      params_hash = { agent_ids: [] }
      Sidekiq::Testing.inline! do
        put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      end
      agent1.reload
      agent2.reload
      assert agent1.freshcaller_agent.present?
      assert_equal agent1.freshcaller_agent.fc_user_id, 1234
      refute agent1.freshcaller_agent.fc_enabled
      assert agent2.freshcaller_agent.present?
      assert_equal agent2.freshcaller_agent.fc_user_id, 5678
      refute agent2.freshcaller_agent.fc_enabled
      assert_response 204
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      remove_stubs
    end

    def test_update_agents_to_add_and_remove_new_agents
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_create_users
      agent1 = add_test_agent(@account).agent
      agent2 = add_test_agent(@account).agent
      agent2.create_freshcaller_agent(
        fc_enabled: true,
        fc_user_id: 5678
      )
      params_hash = { agent_ids: [agent1.user.id] }
      Sidekiq::Testing.inline! do
        put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      end
      agent1.reload
      agent2.reload
      assert agent1.freshcaller_agent.present?
      assert_equal agent1.freshcaller_agent.fc_user_id, 111
      assert agent1.freshcaller_agent.fc_enabled
      assert agent2.freshcaller_agent.present?
      assert_equal agent2.freshcaller_agent.fc_user_id, 5678
      refute agent2.freshcaller_agent.fc_enabled
      assert_response 204
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      remove_stubs
    end

    def test_update_agents_existing_freshcaller_agent
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_create_users_already_present_error
      agent1 = add_test_agent(@account).agent
      agent1.create_freshcaller_agent(
        fc_enabled: false,
        fc_user_id: 5678
      )
      params_hash = { agent_ids: [agent1.user.id] }
      Sidekiq::Testing.inline! do
        put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      end
      agent1.reload
      assert agent1.freshcaller_agent.present?
      assert_equal agent1.freshcaller_agent.fc_user_id, 5678
      assert agent1.freshcaller_agent.fc_enabled
      assert_response 204
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      remove_stubs
    end

    def test_update_agents_limit_exceeded
      create_freshcaller_account unless Account.current.freshcaller_account
      stub_create_users_agent_limit_error
      agent1 = add_test_agent(@account).agent
      params_hash = { agent_ids: [agent1.user.id] }
      Sidekiq::Testing.inline! do
        put :update, construct_params({ version: 'private' }.merge(params_hash), params_hash)
      end
      agent1.reload
      refute agent1.freshcaller_agent.present?
      assert_response 204
    ensure
      delete_freshcaller_account
      delete_freshcaller_agent unless @agent.agent.freshcaller_agent.nil?
      remove_stubs
    end
  end
end
