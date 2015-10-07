require_relative '../unit_test_helper'

class DataTypeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :array, :hash, :error_options, :string_param, :allow_string_boolean, :boolean, :multi_error

    validates :multi_error, required: true
    validates :array, :multi_error, data_type: { rules: Array, allow_nil: true }
    validates :hash, data_type: { rules: Hash }
    validates :boolean, data_type: { rules: 'Boolean', allow_nil: true }
    validates :allow_string_boolean, data_type: { rules: 'Boolean', ignore_string: :string_param, allow_nil: true }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.hash = [nil]
    test.multi_error = [1, 2]
    refute test.valid?
    errors = [test.errors.to_h, test.error_options.to_h]
    assert_equal([{ hash: 'data_type_mismatch' }, { hash: { data_type: 'key/value pair' } }], errors)
  end

  def test_valid_values
    test = TestValidation.new
    test.string_param = true
    test.array = [1, 2]
    test.multi_error = [1, 2]
    test.hash = { a: 1 }
    test.boolean = true
    test.allow_string_boolean = 'false'
    assert test.valid?
    assert test.errors.empty?
  end

  def test_allow_nil
    test = TestValidation.new
    test.array = [nil]
    test.multi_error = [1, 2]
    test.hash = { a: 1 }
    assert test.valid?
    assert test.errors.empty?
  end

  def test_attributes_multiple_error
    test = TestValidation.new
    test.hash = {o: 9}
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({multi_error: 'missing'}, test.errors.to_h)
  end

  def test_valid_values_invalid
    test = TestValidation.new
    test.string_param = false
    test.array = 1
    test.hash = 2
    test.boolean = 'true'
    test.allow_string_boolean = 'false'
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ array: 'data_type_mismatch', hash: 'data_type_mismatch', boolean: 'data_type_mismatch', allow_string_boolean: 'data_type_mismatch', multi_error: 'missing' }, errors)
  end
end
