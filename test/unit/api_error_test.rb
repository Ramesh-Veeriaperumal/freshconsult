require_relative '../test_helper'

class ApiErrorTest < ActionView::TestCase
  include ApiError
 
  test "should return the base error object" do
    base_error = ApiError::BaseError.new(ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal base_error.message, I18n.t("api.error_messages.#{ApiError::BaseError::API_ERROR_CODES[0][0]}")
  end

  test "should return the bad request error object" do
    base_error = ApiError::BadRequestError.new("name", ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal base_error.message,  I18n.t("api.error_messages.#{ApiError::BaseError::API_ERROR_CODES[0][0]}")
    assert_equal base_error.http_code, ApiError::BaseError::API_ERROR_CODES[0][2]
    assert_equal base_error.field, "name"
    assert_equal base_error.code, ApiError::BaseError::API_ERROR_CODES[0][1]
  end

  def test_request_error_without_params
    base_error = ApiError::RequestError.new("access_denied")
    assert_equal base_error.message, "You are not authorized to perform this action."
    assert_equal base_error.code, "access_denied"
  end

  def test_request_error_with_params
    base_error = ApiError::RequestError.new("require_feature", {:feature => "Forums"}) 
    assert_equal base_error.message, "The Forums feature is not supported in your plan. Please upgrade your account to use it."
    assert_equal base_error.code, "require_feature"
  end
end