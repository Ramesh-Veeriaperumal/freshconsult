require_relative '../unit_test_helper'

class BadRequestErrorTest < ActionView::TestCase
  def test_base_error_code_mapping
    error_codes =  {
      missing_field: ['missing_field', 'Mandatory attribute missing', 'requester_id_mandatory',
                      'phone_mandatory', 'fill_a_mandatory_field', 'company_id_required'],
      duplicate_value: ['has already been taken', 'already exists in the selected category', 'Email has already been taken'],
      invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
      invalid_field: ['invalid_field', "Can't update user when timer is running"],
      data_type_mismatch: ['is not a number', 'data_type_mismatch', 'must be an integer', 'per_page_invalid'],
      invalid_size: ['invalid_size'],
      incompatible_field: ['incompatible_field'],
      inaccessible_field: ['inaccessible_field', 'require_feature_for_attribute']
    }

    assert_equal error_codes, ErrorConstants::API_ERROR_CODES

    # this will not save against all the messages for invalid_value custom_code
    expected = [:"Mandatory attribute missing", :"Can't update user when timer is running"]
    actual = ErrorConstants::API_ERROR_CODES.values.flatten.map(&:to_sym) - ErrorConstants::ERROR_MESSAGES.keys
    assert_equal expected, actual

    actual = ErrorConstants::API_ERROR_CODES.values.flatten.map(&:to_sym) + [:new_key_sans_yml] - ErrorConstants::ERROR_MESSAGES.keys
    assert_not_equal expected, actual
  end

  def test_missing_field_code
    missing_field_messages = { :missing_field => {}, :"Mandatory attribute missing" => {},
                               :requester_id_mandatory => {}, :phone_mandatory => {}, :not_included => { code: :missing_field, list: '2,3' }, :data_type_mismatch => { code: :missing_field, data_type: String },
                               :invalid_date => { code: :missing_field },  :invalid_format => { code: :missing_field } }
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
      assert_equal 'data_type_mismatch', test.code.to_s
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
