require_relative '../test_helper'

class ApiErrorTest < ActionView::TestCase
  include ApiError
 
  test "should return the base error object" do
    base_error = ApiError::BaseError.new(ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal base_error.message, ApiError::BaseError::API_ERROR_CODES[0][2]
    assert_equal base_error.http_code, ApiError::BaseError::API_ERROR_CODES[0][3]
  end

  test "should return the bad request error object" do
    base_error = ApiError::BadRequestError.new("name", ApiError::BaseError::API_ERROR_CODES[0][0])
    assert_equal base_error.message, ApiError::BaseError::API_ERROR_CODES[0][2]
    assert_equal base_error.http_code, ApiError::BaseError::API_ERROR_CODES[0][3]
    assert_equal base_error.field, "name"
    assert_equal base_error.code, ApiError::BaseError::API_ERROR_CODES[0][1]
  end
end