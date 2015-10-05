require_relative '../unit_test_helper'

class DataTypeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :array, :hash, :error_options, :string_param, :allow_string_boolean, :boolean
    validates :array, data_type: { rules: Array, allow_nil: true }
    validates :hash, data_type: { rules: Hash }
    validates :boolean, data_type: { rules: 'Boolean', allow_nil: true }
    validates :allow_string_boolean, data_type: { rules: 'Boolean', ignore_string: :string_param, allow_nil: true }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.hash = [nil]
    refute test.valid?
    errors = [test.errors.to_h, test.error_options.to_h]
    assert_equal([{ hash: 'data_type_mismatch' }, { hash: { data_type: 'key/value pair' } }], errors)
  end

  def test_valid_values
    test = TestValidation.new
    test.string_param = true
    test.array = [1, 2]
    test.hash = { a: 1 }
    test.boolean = true
    test.allow_string_boolean = "false"
    assert test.valid?
    assert test.errors.empty?
  end

  def test_allow_nil
    test = TestValidation.new
    test.array = [nil]
    test.hash = { a: 1 }
    assert test.valid?
    assert test.errors.empty?
  end

  def test_valid_values_invalid
    test = TestValidation.new
    test.string_param = false
    test.array = 1
    test.hash = 2
    test.boolean = "true"
    test.allow_string_boolean = "false"
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ array: 'data_type_mismatch', hash: 'data_type_mismatch', boolean: 'data_type_mismatch', :allow_string_boolean => 'data_type_mismatch' }, errors)
  end
end
