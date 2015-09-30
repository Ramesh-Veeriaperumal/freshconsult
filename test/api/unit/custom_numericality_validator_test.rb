require_relative '../unit_test_helper'

class CustomNumericalityValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :attribute3, :attribute4, :error_options
    validates :attribute1, custom_numericality: { allow_nil: true }
    validates :attribute2, custom_numericality: { allow_nil: false }
    validates :attribute3, custom_numericality: { allow_negative: true, allow_nil: true }
    validates :attribute4, custom_numericality: { allow_negative: true, allow_nil: true, message: 'only integers are allowed' }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.attribute2 = nil
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: 'data_type_mismatch' }, errors)
    assert_equal({ attribute2: { data_type: 'Positive Integer' } }, error_options)
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
    assert test.valid?
    assert test.errors.empty?
  end

  def test_custom_message
    test = TestValidation.new
    test.attribute2 = 1
    test.attribute4 = '909'
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute4: 'only integers are allowed' }, errors)
    assert_equal({ attribute4: { data_type: 'Integer' } }, error_options)
  end

  def test_invalid_values
    test = TestValidation.new
    test.attribute1 = -1
    test.attribute2 = -1
    test.attribute3 = '9099'
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: 'data_type_mismatch', attribute1: 'data_type_mismatch', attribute3: 'data_type_mismatch' }.sort.to_h, errors.sort.to_h)
    assert_equal({ attribute2: { data_type: 'Positive Integer' }, attribute1: { data_type: 'Positive Integer' }, attribute3: { data_type: 'Integer' } }.sort.to_h, error_options.sort.to_h)
  end
end
