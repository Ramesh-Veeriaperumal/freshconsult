require_relative '../unit_test_helper'

class ErrorHelperTest < ActionView::TestCase
  def test_format_error
    error_array = { 'requester_id' => :duplicate_value, 'email' => :'has already been taken', 'error_field' => :invalid_field }
    @errors = ErrorHelper.format_error(error_array)
    assert_equal @errors.count, error_array.count
    @errors.each.with_index do |error, i|
      code = ErrorConstants::API_ERROR_CODES_BY_VALUE[error_array.values[i]] || 'invalid_value'
      assert_equal error_array.keys[i].to_sym, error.field
      assert_equal (ErrorConstants::API_HTTP_ERROR_STATUS_BY_CODE[code] || 400), error.http_code
      assert_equal ErrorConstants::ERROR_MESSAGES[error_array.values[i].to_sym], error.message
      assert_equal code, error.code
    end
  end

  def test_format_error_with_meta_as_stringified_key_hash
    error_hash = { cf_fruit_1: :not_included }
    meta = { 'cf_fruit_1': { list: 'Mango,Apple' } }
    @errors = ErrorHelper.format_error(error_hash, meta)
    assert_equal 1, @errors.count
    @errors.each.with_index do |error, i|
      assert_equal error_hash.keys[i].to_sym, error.field
      assert_equal 400, error.http_code
      assert_equal format(ErrorConstants::ERROR_MESSAGES[error_hash.values[i].to_sym], list: 'Mango,Apple'), error.message
      assert_equal 'invalid_value', error.code
    end
  end

  def test_format_error_with_meta_as_symbolized_key_hash
    error_hash = { cf_fruit_1: :not_included }
    meta = { cf_fruit_1: { list: 'Mango,Apple' } }
    @errors = ErrorHelper.format_error(error_hash, meta)
    assert_equal 1, @errors.count
    @errors.each.with_index do |error, i|
      assert_equal error_hash.keys[i].to_sym, error.field
      assert_equal 400, error.http_code
      assert_equal format(ErrorConstants::ERROR_MESSAGES[error_hash.values[i].to_sym], list: 'Mango,Apple'), error.message
      assert_equal 'invalid_value', error.code
    end
  end

  def test_find_http_error_code
    errors = []
    [:"can't be blank", :'has already been taken'].each do |value|
      errors << BadRequestError.new('name', value)
    end
    code = ErrorHelper.find_http_error_code(errors)
    assert_equal 400, code
  end
end
