require_relative '../../../test_helper'

module Ember::Search
  class LoggerControllerTest < ActionController::TestCase
    include PrivilegesHelper

    def test_log_click_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :log_click, construct_params(version: 'private', data: {})
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_log_click_with_access
      post :log_click, construct_params(version: 'private', data: { term: 'sample', positionIndex: 4, pageNumber: 1 })
      assert_response 204
    end
  end
end
