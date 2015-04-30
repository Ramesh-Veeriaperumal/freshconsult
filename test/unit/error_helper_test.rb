require_relative '../test_helper'

class ErrorHelperTest < ActionView::TestCase
  include ErrorHelper
 
  def test_format_error
    error_array = {"name" => ["can't be blank"], "email" => ["has already been taken"], "error_field" => ["invalid_field"]}
    @errors = format_error(error_array)
    assert_equal @errors.count, error_array.count
    i=0
    @errors.each do |error|
       assert_equal error_array.keys[i], error.field
       assert_equal ApiError::BaseError::API_HTTP_ERROR_STATUS_BY_VALUE[error_array.keys[i]], error.http_code
       assert_equal I18n.t("api.error_messages.#{error_array.values[i]}"), error.message
       assert_equal ApiError::BaseError::API_ERROR_CODES_BY_VALUE[error_array.keys[i]], error.code
       i+=1
    end
  end

  def test_find_http_error_code
    errors = []
    ["can't be blank", "has already been taken"].each do |value|
      errors << ApiError::BadRequestError.new("name", value)
    end
    code = find_http_error_code(errors)
    assert_equal 400, code
  end
end