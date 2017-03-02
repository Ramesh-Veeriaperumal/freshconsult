require_relative '../unit_test_helper'

class CustomNumericalityValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :attribute3, :attribute4, :attribute5, :allow_string_param, :multi_error

    validates :multi_error, data_type: { rules: Fixnum, allow_nil: true }
    validates :multi_error, custom_numericality: { allow_nil: true, only_integer: true, greater_than: 0 }
    validates :attribute1, custom_numericality: { allow_nil: true, only_integer: true, greater_than: 0 }
    validates :attribute2, custom_numericality: { allow_nil: false, only_integer: true, greater_than: 0 }
    validates :attribute3, custom_numericality: { only_integer: true, allow_nil: true }
    validates :attribute4, custom_numericality: { only_integer: true, allow_nil: true, custom_message: 'only integers are allowed' }
    validates :attribute5, custom_numericality: { ignore_string: :allow_string_param, only_integer: true, greater_than: 0, allow_nil: true }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.attribute2 = nil
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :datatype_mismatch }, errors)
    assert_equal({ attribute2: {  expected_data_type: :'Positive Integer', prepend_msg: :input_received,
                                  given_data_type: 'Null', code: :datatype_mismatch  } }, error_options)
  end

  def test_allow_nil
    test = TestValidation.new
    test.attribute1 = nil
    test.attribute2 = 2
    assert test.valid?
    assert test.errors.empty?
  end

  def test_valid_values
    test = TestValidation.new
    test.attribute1 = 1
    test.attribute2 = 1
    test.attribute3 = -2
    test.attribute5 = '787'
    test.allow_string_param = true
    assert test.valid?
    assert test.errors.empty?
  end

  def test_attributes_multiple_error
    test = TestValidation.new
    test.attribute2 = 1
    test.multi_error = '890'
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({ multi_error: :datatype_mismatch }, test.errors.to_h)
  end

  def test_custom_message
    test = TestValidation.new
    test.attribute2 = 1
    test.attribute4 = '909'
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute4: 'only integers are allowed' }, errors)
  end

  def test_invalid_values
    test = TestValidation.new
    test.attribute1 = -1
    test.attribute2 = -1
    test.attribute3 = '9099'
    test.attribute5 = '67'
    test.allow_string_param = false
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :datatype_mismatch, attribute1: :datatype_mismatch, attribute3: :datatype_mismatch, attribute5: :datatype_mismatch }.sort.to_h, errors.sort.to_h)
    assert_equal({ attribute2: {  expected_data_type: :'Positive Integer', code: :invalid_value }, attribute1: {  expected_data_type: :'Positive Integer', code: :invalid_value }, attribute3: {  expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch }, attribute5: {  expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch } }.sort.to_h, error_options.sort.to_h)
  end
end
