require_relative '../../../test_helper'

module Ember::Search
  class CustomersControllerTest < ActionController::TestCase

    def test_result_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.words, searchSort:"relevance"})
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end
  end
end