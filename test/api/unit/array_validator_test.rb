require_relative '../unit_test_helper'

class ArrayValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :emails, :domains, :attributes, :multi_error, :error_options
    # traditional validator
    validates :emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'not_a_valid_email' } }
    # custom validator
    validates :domains, array: { data_type: { rules: String, allow_blank: true } }
    validates :attributes, array: { numericality: true }
    validates :multi_error, data_type: { rules: Array }, array: { data_type: { rules: String, allow_blank: true } }, allow_blank: true
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
    assert_equal({ emails: 'not_a_valid_email', domains: :data_type_mismatch }, errors)
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
    assert_equal({ attributes: "is not a number" }, errors)
  end

  def test_attribute_with_errors
    test = TestValidation.new
    test.multi_error = 'Junk String'
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ multi_error: :data_type_mismatch }, errors)
    assert errors.count == 1
  end
end
