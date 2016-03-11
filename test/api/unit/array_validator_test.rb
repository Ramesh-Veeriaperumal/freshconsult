require_relative '../unit_test_helper'

class ArrayValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :emails, :domains, :attributes, :multi_error

    # traditional validator
    validates :emails, array: { custom_format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, accepted: :'valid email address' } }
    # custom validator
    validates :domains, array: {  data_type: { rules: String, allow_blank: true } }
    validates :attributes, array: { custom_numericality: true }
    validates :multi_error, data_type: { rules: Array }, array: {  data_type: { rules: String, allow_blank: true } }, allow_blank: true
  end

  def test_array_allow_nil_blank
    test = TestValidation.new
    test.emails = [nil, nil]
    test.domains = ['', '']
    test.attributes = [1]
    assert test.valid?
    assert test.errors.empty?
  end

  def test_array_invalid_values
    test = TestValidation.new
    test.emails = [1, 2]
    test.domains = [1, 2]
    test.attributes = [1]
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ emails: :array_invalid_format, domains: :array_datatype_mismatch }, errors)
    assert_equal({ emails: { accepted: :"valid email address" }, domains: { expected_data_type: String }, attributes: {} }, test.error_options)
  end

  def test_array_valid_values
    test = TestValidation.new
    test.emails = ['a@b.com', 'c@d.com']
    test.domains = ['test', 'rest']
    test.attributes = [1]
    assert test.valid?
    assert test.errors.empty?
  end

  def test_array_disallow_nil
    test = TestValidation.new
    test.attributes = [nil]
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ attributes: :array_datatype_mismatch }, errors)
    assert_equal({ attributes: { expected_data_type: :Number } }, test.error_options)
  end

  def test_attribute_with_errors
    test = TestValidation.new
    test.multi_error = 'Junk String'
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ multi_error: :datatype_mismatch }, errors)
    assert_equal({ multi_error: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String } }, test.error_options)
    assert errors.count == 1
  end
end
