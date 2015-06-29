require_relative '../test_helper'

class ErrorHelperTest < ActionView::TestCase
  def test_format_error
    error_array = { 'name' => "can't be blank", 'email' => 'has already been taken', 'error_field' => 'invalid_field' }
    @errors = ErrorHelper.format_error(error_array)
    assert_equal @errors.count, error_array.count
    @errors.each.with_index do |error, i|
      code = BaseError::API_ERROR_CODES_BY_VALUE[error_array.values[i]] || 'invalid_value'
      assert_equal error_array.keys[i], error.field
      assert_equal (BaseError::API_HTTP_ERROR_STATUS_BY_CODE[code] || 400), error.http_code
      assert_equal I18n.t("api.error_messages.#{error_array.values[i]}"), error.message
      assert_equal code, error.code
    end
  end

  def test_find_http_error_code
    errors = []
    ["can't be blank", 'has already been taken'].each do |value|
      errors << BadRequestError.new('name', value)
    end
    code = ErrorHelper.find_http_error_code(errors)
    assert_equal 400, code
  end
end
