require_relative '../../test_helper'
['automations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module ApiSearch
  class AutomationsControllerTest < ActionController::TestCase
    include AutomationTestHelper

    def test_automations_search_by_name
      get :results, construct_params(term: 'rule', query: 'actions:priority')
      assert_response 200
    end

    def test_automations_search_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      get :results, construct_params(term: 'rule', query: 'actions:priority')
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end
  end
end
