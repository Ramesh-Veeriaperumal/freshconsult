require_relative '../unit_test_helper'

class BadRequestErrorTest < ActionView::TestCase

    def test_base_error_code_mapping
      error_codes = {
        missing_field: ['missing_field', 'Mandatory attribute missing', 'missing',
                        'requester_id_mandatory', 'phone_mandatory', 'required_and_numericality',
                        'required_and_inclusion', 'required_boolean', 'required_number', 'required_integer', 'required_date', 'required_format'],
        duplicate_value: ['has already been taken', 'already exists in the selected category', 'Email has already been taken'],
        invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
        datatype_mismatch: ['is not a date', 'is not a number', 'data_type_mismatch', 'must be an integer', 'positive_number'],
        invalid_field: ['invalid_field', "Can't update user when timer is running"],
        invalid_size: ['invalid_size']
        }
      assert_equal error_codes, BaseError::API_ERROR_CODES
    end

    def test_missing_field_code
      missing_field_messages = {'missing_field' => {}, 'Mandatory attribute missing' => {}, 'missing' => {},
                    'requester_id_mandatory' => {}, 'phone_mandatory' => {}, 'required_and_numericality' => {},
                    'required_and_inclusion' => {list: '2,3'}, 'required_boolean' => {}, 'required_number' => {}, 
                    'required_integer' => {},  'required_date' => {},  'required_format' => {}}
      missing_field_messages.each do |message, params|
        test = BadRequestError.new("attribute", message, params)
        assert_equal 'missing_field', test.code.to_s
        assert_equal 400, test.http_code
        assert_equal 'attribute', test.field
      end
    end

    def test_duplicate_code
      duplicate_code_messages = ['has already been taken', 'already exists in the selected category', 'Email has already been taken']
      duplicate_code_messages.each do |message|
        test = BadRequestError.new("attribute", message)
        assert_equal 'duplicate_value', test.code.to_s
        assert_equal 409, test.http_code
        assert_equal 'attribute', test.field
      end
    end

    def test_invalid_value_code
      invalid_code_messages = {"can't be blank" => {}, 'junk_message' => {}, 'is not included in the list' => {list: '1,2'}, 'invalid_user' => {id: 1, name: "name"}}
      invalid_code_messages.each do |message, params|
        test = BadRequestError.new("attribute", message, params)
        assert_equal 'invalid_value', test.code.to_s
        assert_equal 400, test.http_code
        assert_equal 'attribute', test.field
      end
    end

    def test_data_type_mismatch_code
      datatype_mismatch_messages = {'is not a date' => {}, 'is not a number' => {}, 'data_type_mismatch' => {data_type: 'date'}, 'must be an integer' => {}, 'positive_number' => {}}
      datatype_mismatch_messages.each do |message, params|
        test = BadRequestError.new("attribute", message, params)
        assert_equal 'datatype_mismatch', test.code.to_s
        assert_equal 400, test.http_code
        assert_equal 'attribute', test.field
      end
    end

    def test_invalid_field_code
      invalid_field_messages = ['invalid_field', "Can't update user when timer is running"]
      invalid_field_messages.each do |message|
        test = BadRequestError.new("attribute", message)
        assert_equal 'invalid_field', test.code.to_s
        assert_equal 400, test.http_code
        assert_equal 'attribute', test.field
      end
    end

    def test_invalid_size_code
      invalid_size_messages = {'invalid_size' => {max_size: 78}}
      invalid_size_messages.each do |message, params|
        test = BadRequestError.new("attribute", message, params)
        assert_equal 'invalid_size', test.code.to_s
        assert_equal 400, test.http_code
        assert_equal 'attribute', test.field
      end
    end
end
