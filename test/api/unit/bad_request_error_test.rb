require_relative '../unit_test_helper'

class BadRequestErrorTest < ActionView::TestCase
  def test_base_error_code_mapping
    # this will not save against all the messages for invalid_value custom_code
    assert_equal [], ErrorConstants::API_ERROR_CODES.values.flatten.map(&:to_sym) - ErrorConstants::ERROR_MESSAGES.keys
  end

  def test_missing_field_code
    missing_field_messages = { missing_field: {}, not_included: { code: :missing_field, list: '2,3' },
                               datatype_mismatch: { code: :missing_field, expected_data_type: String }, invalid_format: { code: :missing_field, accepted: :test } }
    missing_field_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'missing_field', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_duplicate_code
    duplicate_code_messages = [:'has already been taken', :'already exists in the selected category', :'Email has already been taken']
    duplicate_code_messages.each do |message|
      test = BadRequestError.new('attribute', message)
      assert_equal 'duplicate_value', test.code.to_s
      assert_equal 409, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_invalid_value_code
    invalid_code_messages = { :"can't be blank" => {}, :junk_message => {}, :'is not included in the list' => { list: '1,2' }, :invalid_user => { id: 1, name: 'name' } }
    invalid_code_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'invalid_value', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_invalid_size_code
    invalid_size_messages = { invalid_size: { max_size: 78, current_size: 79 } }
    invalid_size_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'invalid_size', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_nested_field_error
    test = BadRequestError.new(
      'attribute', :missing_field, {
        nested_field: 'nested_field'
      }
    )
    assert_equal 'missing_field', test.code.to_s
    assert_equal 400, test.http_code
    assert_equal 'attribute', test.field
    assert_equal 'nested_field', test.nested_field
  end

end
