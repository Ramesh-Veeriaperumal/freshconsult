require_relative '../unit_test_helper'

class DataTypeValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :array, :hash, :allow_unset_param, :allow_string_param, :required_param, :allow_string_boolean, :boolean, :multi_error, :set_boolean

    validates :multi_error, required: true
    validates :allow_unset_param, data_type: { rules: String, allow_unset: true }
    validates :required_param, data_type: { rules: Array, required: true }
    validates :array, :multi_error, data_type: { rules: Array, allow_nil: false, allow_unset: true }
    validates :hash, data_type: { rules: Hash, allow_nil: false, allow_unset: true }
    validates :boolean, data_type: { rules: 'Boolean', allow_nil: true }
    validates :allow_string_boolean, data_type: { rules: 'Boolean', ignore_string: :allow_string_param, allow_nil: true }
    validates :set_boolean, data_type: { rules: 'Boolean', allow_unset: true }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.hash = nil
    test.array = nil
    test.required_param = [1, 2, 3]
    test.multi_error = [1, 2]
    refute test.valid?
    errors = [test.errors.to_h.sort, test.error_options.to_h.sort]
    assert_equal([{ hash: :data_type_mismatch, array: :data_type_mismatch }.sort, { hash: {  expected_data_type: 'key/value pair',
                                                                                             given_data_type: 'Null Type', prepend_msg: :input_received }, array: {  expected_data_type: Array, given_data_type: 'Null Type', prepend_msg: :input_received }, multi_error: {}, required_param: {} }.sort], errors)
  end

  def test_valid_values
    test = TestValidation.new
    test.allow_string_param = true
    test.array = [1, 2]
    test.multi_error = [1, 2]
    test.hash = { a: 1 }
    test.boolean = true
    test.required_param = [1, 2, 3]
    test.allow_string_boolean = 'false'
    assert test.valid?
    assert test.errors.empty?
  end

  def test_allow_nil
    test = TestValidation.new
    test.multi_error = [1, 2]
    test.hash = { a: 1 }
    test.boolean = nil
    test.required_param = [1, 2, 3]
    assert test.valid?
    assert test.errors.empty?
  end

  def test_allow_unset_invalid
    test = TestValidation.new
    test.allow_string_param = true
    test.allow_unset_param = nil
    test.multi_error = [1, 2]
    test.boolean = true
    test.required_param = [1, 2, 3]
    test.allow_string_boolean = 'false'
    refute test.valid?
    assert_equal({ allow_unset_param: :data_type_mismatch }, test.errors.to_h)
    assert_equal({ allow_unset_param: {  expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null Type',
                                         prepend_msg: :input_received }, boolean: {}, allow_string_boolean: {}, multi_error: {}, required_param: {} },  test.error_options.to_h)
  end

  def test_attributes_multiple_error
    test = TestValidation.new
    test.hash = { o: 9 }
    test.required_param = [1, 2, 3]
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({ multi_error: :missing_field }, test.errors.to_h)
  end

  def test_valid_values_invalid
    test = TestValidation.new
    test.allow_string_param = false
    test.array = { 1 => 2 }
    test.hash = [1, 2, 3]
    test.boolean = 'true'
    test.allow_string_boolean = 'false'
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({ array: :data_type_mismatch, hash: :data_type_mismatch, boolean: :data_type_mismatch, allow_string_boolean: :data_type_mismatch, multi_error: :missing_field, required_param: :data_type_mismatch }.sort, errors)
    assert_equal({ allow_string_boolean: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String }, array: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' }, boolean: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String }, hash: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array }, multi_error: {}, required_param: { expected_data_type: Array, code: :missing_field } }.sort, error_options)
  end

  def test_allow_unset
    test = TestValidation.new
    test.set_boolean = nil
    test.array = [1, 2]
    test.multi_error = [1, 2]
    test.hash = { a: 1 }
    test.boolean = true
    test.required_param = [1, 2, 3]
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({ set_boolean: :data_type_mismatch }.sort, errors)
    assert_equal({ set_boolean:  {  expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null Type',
                                    prepend_msg: :input_received }, boolean: {}, array: {}, hash: {}, multi_error: {}, required_param: {} }.sort, error_options)
  end
end
