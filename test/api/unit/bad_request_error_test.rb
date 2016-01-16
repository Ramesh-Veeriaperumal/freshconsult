require_relative '../unit_test_helper'

class BadRequestErrorTest < ActionView::TestCase
  def test_base_error_code_mapping
    error_codes =  {
      missing_field: ['missing_field', 'Mandatory attribute missing', 'missing', 'requester_id_mandatory',
                      'phone_mandatory', 'required_and_numericality', 'required_and_inclusion', 'required_and_data_type_mismatch',
                      'required_boolean', 'required_number', 'required_integer', 'required_date', 'required_format',
                      'fill_a_mandatory_field', 'company_id_required', 'required_and_invalid_number'],
      duplicate_value: ['has already been taken', 'already exists in the selected category', 'Email has already been taken'],
      invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
      invalid_field: ['invalid_field', "Can't update user when timer is running"],
      datatype_mismatch: ['is not a number', 'data_type_mismatch', 'must be an integer', 'per_page_data_type_mismatch'],
      invalid_size: ['invalid_size'],
      incompatible_field: ['incompatible_field'],
      inaccessible_field: ['inaccessible_field']
    }

    assert_equal error_codes, ErrorConstants::API_ERROR_CODES

    # this will not save against all the messages for invalid_value custom_code
    expected = [:"Mandatory attribute missing", :"Email has already been taken", :"Can't update user when timer is running"]
    actual = ErrorConstants::API_ERROR_CODES.values.flatten.map(&:to_sym) - ErrorConstants::ERROR_MESSAGES.keys
    assert_equal expected, actual

    expected = [:"Mandatory attribute missing", :"Email has already been taken", :"Can't update user when timer is running"]
    actual = ErrorConstants::API_ERROR_CODES.values.flatten.map(&:to_sym) + [:new_key_sans_yml] - ErrorConstants::ERROR_MESSAGES.keys
    assert_not_equal expected, actual
  end

  def test_missing_field_code
    missing_field_messages = { :missing_field => {}, :"Mandatory attribute missing" => {}, :missing => {},
                               :requester_id_mandatory => {}, :phone_mandatory => {}, :required_and_numericality => {},
                               :required_and_inclusion => { list: '2,3' }, :required_boolean => {}, :required_number => {},
                               :required_integer => {},  :required_date => {},  :required_format => {} }
    missing_field_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'missing_field', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_duplicate_code
    duplicate_code_messages = [:"has already been taken", :"already exists in the selected category", :"Email has already been taken"]
    duplicate_code_messages.each do |message|
      test = BadRequestError.new('attribute', message)
      assert_equal 'duplicate_value', test.code.to_s
      assert_equal 409, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_invalid_value_code
    invalid_code_messages = { :"can't be blank" => {}, :junk_message => {}, :"is not included in the list" => { list: '1,2' }, :invalid_user => { id: 1, name: 'name' } }
    invalid_code_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'invalid_value', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_data_type_mismatch_code
    datatype_mismatch_messages = { :"is not a number" => {}, :data_type_mismatch => { data_type: 'date format' }, :"must be an integer" => {} }
    datatype_mismatch_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'datatype_mismatch', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_invalid_field_code
    invalid_field_messages = [:invalid_field, :"Can't update user when timer is running"]
    invalid_field_messages.each do |message|
      test = BadRequestError.new('attribute', message)
      assert_equal 'invalid_field', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end

  def test_invalid_size_code
    invalid_size_messages = { invalid_size: { max_size: 78 } }
    invalid_size_messages.each do |message, params|
      test = BadRequestError.new('attribute', message, params)
      assert_equal 'invalid_size', test.code.to_s
      assert_equal 400, test.http_code
      assert_equal 'attribute', test.field
    end
  end
end
