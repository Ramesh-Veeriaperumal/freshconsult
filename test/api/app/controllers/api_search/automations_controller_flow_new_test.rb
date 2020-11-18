# frozen_string_literal: true

require_relative '../../../api_test_helper'

['automations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module ApiSearch
  class AutomationsControllerFlowTest < ActionDispatch::IntegrationTest
    include AutomationTestHelper
    include SearchTestHelper

    def test_automations_search_by_name
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      automation = create_service_task_observer_rule('1', 'same_ticket')
      user = add_test_agent(@account)
      set_request_auth_headers(user)
      stub_private_search_response([automation]) do
        account_wrap(user) do
          get '/api/_/search/automations', construct_params(term: 'rule', query: 'actions:priority').to_json, @write_headers
        end
      end
      assert_response 200
      assert_equal JSON.parse(response.body)['meta']['count'], 1
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    end

    def test_automations_search_by_name_without_results
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      user = add_test_agent(@account)
      set_request_auth_headers(user)
      stub_private_search_response([]) do
        account_wrap(user) do
          get '/api/_/search/automations', construct_params(term: 'rule', query: 'actions:priority').to_json, @write_headers
        end
      end
      assert_response 200
      assert_equal JSON.parse(response.body)['meta']['count'], 0
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    end

    def test_automations_search_by_name_without_user_access
      @initial_private_api_request = CustomRequestStore.store[:private_api_request]
      CustomRequestStore.store[:private_api_request] = true
      user = add_new_user(@account)
      set_request_auth_headers(user)
      account_wrap(user) do
        get '/api/_/search/automations', construct_params(term: 'rule', query: 'actions:priority')
      end
      assert_response 403
    ensure
      CustomRequestStore.store[:private_api_request] = @initial_private_api_request
    end
  end
end
