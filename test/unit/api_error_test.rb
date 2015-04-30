require_relative '../test_helper'

class ApiErrorTest < ActionView::TestCase
  include ApiError
 
  def test_base_error
    base_error = ApiError::BaseError.new(ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal I18n.t("api.error_messages.#{ApiError::BaseError::API_ERROR_CODES[0][0]}"), base_error.message
  end

  def test_bad_request
    base_error = ApiError::BadRequestError.new("name", ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal I18n.t("api.error_messages.#{ApiError::BaseError::API_ERROR_CODES[0][0]}"), base_error.message
    assert_equal ApiError::BaseError::API_ERROR_CODES[0][2], base_error.http_code
    assert_equal "name", base_error.field
    assert_equal ApiError::BaseError::API_ERROR_CODES[0][1], base_error.code
  end

  def test_request_error_without_params
    base_error = ApiError::RequestError.new("access_denied")
    assert_equal "You are not authorized to perform this action.", base_error.message
    assert_equal "access_denied", base_error.code
  end

  def test_request_error_with_params
    base_error = ApiError::RequestError.new("require_feature", {:feature => "Forums"}) 
    assert_equal "The Forums feature is not supported in your plan. Please upgrade your account to use it.", base_error.message
    assert_equal "require_feature", base_error.code
  end
end