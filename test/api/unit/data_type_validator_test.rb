require_relative '../unit_test_helper'

class DataTypeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :array, :hash, :error_options, :allow_unset_param, :allow_string_param, :required_param, :allow_string_boolean, :boolean, :multi_error

    validates :multi_error, required: true
    validates :allow_unset_param, data_type: { rules: String, allow_unset: true }
    validates :required_param, data_type: { rules: Array, required: true }
    validates :array, :multi_error, data_type: { rules: Array, allow_nil: false }
    validates :hash, data_type: { rules: Hash, allow_nil: false }
    validates :boolean, data_type: { rules: 'Boolean', allow_nil: true }
    validates :allow_string_boolean, data_type: { rules: 'Boolean', ignore_string: :allow_string_param, allow_nil: true }
  end

  def test_disallow_nil
    test = TestValidation.new
    test.hash = nil
    test.array = nil
    test.required_param = [1, 2, 3]
    test.multi_error = [1, 2]
    refute test.valid?
    errors = [test.errors.to_h.sort, test.error_options.to_h.sort]
    assert_equal([{ hash: 'data_type_mismatch', array: 'data_type_mismatch' }.sort, { hash: { data_type: 'key/value pair' }, array: { data_type: Array } }.sort], errors)
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
    assert_equal({ allow_unset_param: 'data_type_mismatch' }, test.errors.to_h)
    assert_equal({ allow_unset_param: { data_type: String } },  test.error_options.to_h)
  end

  def test_attributes_multiple_error
    test = TestValidation.new
    test.hash = { o: 9 }
    test.required_param = [1, 2, 3]
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({ multi_error: 'missing' }, test.errors.to_h)
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
    assert_equal({ array: 'data_type_mismatch', hash: 'data_type_mismatch', boolean: 'data_type_mismatch', allow_string_boolean: 'data_type_mismatch', multi_error: 'missing', required_param: 'required_and_data_type_mismatch' }.sort, errors)
    assert_equal({ array: { data_type: Array }, hash:  { data_type: 'key/value pair' }, boolean:  { data_type: 'Boolean' }, allow_string_boolean:  { data_type: 'Boolean' }, required_param:  { data_type: Array } }.sort, error_options)
  end
end
