require_relative '../test_helper'

class ErrorHelperTest < ActionView::TestCase
  include ErrorHelper
 
  test "should return formatted error for bad request" do
    error_array = {"name" => ["can't be blank"], "email" => ["has already been taken"], "error_field" => ["invalid_field"]}
    format_error(error_array)
    assert_equal @errors.count, error_array.count
    i=0
    @errors.each do |error|
       assert_equal error.field, error_array.keys[i]
       assert_equal error.http_code, ApiError::BaseError::API_HTTP_ERROR_STATUS_BY_VALUE[error_array.keys[i]]
       assert_equal error.message, I18n.t('api.error_messages.#{error_array.keys[i]}')
       assert_equal error.code, ApiError::BaseError::API_ERROR_CODES_BY_VALUE[error_array.keys[i]]
       i+=1
    end
  end

  test "should return http status code for array of mixed errors" do
    errors = []
    ["can't be blank", "has already been taken"].each do |value|
      errors << ApiError::BaseError.new(value)
    end
    code = find_http_error_code(errors)
    assert_equal code, 400
  end
end