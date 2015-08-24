require_relative '../test_helper'

class DataTypeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :array, :hash, :error_options
    validates :array, data_type: { rules: Array, allow_nil: true }
    validates :hash, data_type: { rules: Hash }
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
    test.array = [1, 2]
    test.hash = { a: 1 }
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

  def test_valid_values
    test = TestValidation.new
    test.array = 1
    test.hash = 2
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ array: 'data_type_mismatch', hash: 'data_type_mismatch' }, errors)
  end
end
