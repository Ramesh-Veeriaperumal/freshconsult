# frozen_string_literal: true

require_relative '../../../api_test_helper'

module Ember::Search
  class LoggerControllerTest < ActionDispatch::IntegrationTest
    include PrivilegesHelper

    def test_log_click_without_user_access
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      user = add_new_user(@account)
      set_request_auth_headers(user)
      account_wrap(user) do
        post '/api/_/search_log', construct_params(version: 'private', data: {}, format: :json).to_json, @write_headers
      end
      assert_response 403
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    end

    def test_log_click_with_access
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      user = add_test_agent(@account)
      set_request_auth_headers(user)
      account_wrap(user) do
        post '/api/_/search_log', construct_params(version: 'private', data: { term: 'sample', positionIndex: 4, pageNumber: 1 }, format: :json).to_json, @write_headers
      end
      assert_response 204
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    end

    def test_log_click_with_access_with_exception
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      user = add_test_agent(@account)
      SearchService::ClicksLogger.any_instance.stubs(:log_info).raises(RuntimeError)
      set_request_auth_headers(user)
      account_wrap(user) do
        post '/api/_/search_log', construct_params(version: 'private', data: { term: 'sample', positionIndex: 4, pageNumber: 1 }, format: :json).to_json, @write_headers
      end
      assert_response 204
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
      SearchService::ClicksLogger.any_instance.unstub(:log_info)
    end
  end
end
