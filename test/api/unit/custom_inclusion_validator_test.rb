require_relative '../unit_test_helper'

class CustomInclusionValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :attribute3, :error_options, :allow_string_param, :attribute4, :multi_error, :range_attr
    validates :attribute1, custom_inclusion: { in: [1, 2], message: 'attribute1_invalid', allow_nil: true }
    validates :attribute2, custom_inclusion: { in: [1, 2], required: true }
    validates :attribute3, custom_inclusion: { in: [1, 2], exclude_list: true, allow_blank: true }
    validates :attribute4, custom_inclusion: { in: [1, 2], ignore_string: :allow_string_param, allow_blank: true }
    validates :multi_error, custom_numericality: { allow_nil: true }
    validates :multi_error, custom_inclusion: { in: [8, 9], allow_nil: true }
    validates :range_attr, custom_inclusion: { in: ['a'..'d'], allow_nil: true }
  end

  def test_range_attr_does_not_include_covered_attributes
    test = TestValidation.new
    test.attribute2 = 1
    test.range_attr = 'cc'
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ range_attr: :not_included }, errors)
    assert_equal({ range_attr: { list: 'a..d' } }, error_options)
  end

  def test_custom_message
    test = TestValidation.new
    test.attribute1 = 3
    test.attribute2 = 1
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute1: 'attribute1_invalid' }, errors)
    assert_equal({ attribute1: { list: '1,2' } }, error_options)
  end

  def test_attribute_not_defined
    test = TestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :required_and_inclusion }, errors)
    assert_equal({ attribute2: { list: '1,2' } }, error_options)
  end

  def test_attribute_defined
    test = TestValidation.new
    test.attribute2 = 4
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :not_included }, errors)
    assert_equal({ attribute2: { list: '1,2' } }, error_options)
  end

  def test_error_options_not_defined
    test = TestValidation.new
    test.stubs(:methods).returns([])
    test.attribute2 = 4
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :not_included }, errors)
    assert_equal({}, error_options)
    test.unstub(:methods)
  end

  def test_exclude_list_option_present
    test = TestValidation.new
    test.attribute2 = 1
    test.attribute3 = 4
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute3: :not_included }, errors)
    assert_equal({}, error_options)
  end

  def test_disallow_nil
    test = TestValidation.new
    test.attribute2 = nil
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :not_included }, errors)
    assert_equal({ attribute2: { list: '1,2' } }, error_options)
  end

  def test_allow_nil_and_blank
    test = TestValidation.new
    test.attribute1 = nil
    test.attribute2 = 2
    test.attribute3 = ''
    assert test.valid?
    assert test.errors.empty?
  end

  def test_valid_values
    test = TestValidation.new
    test.attribute1 = 1
    test.attribute2 = 1
    test.attribute3 = 2
    test.attribute4 = '2'
    test.allow_string_param = true
    assert test.valid?
    assert test.errors.empty?
  end

  def test_invalid_values
    test = TestValidation.new
    test.attribute1 = 3
    test.attribute3 = 2
    test.attribute4 = '2'
    test.allow_string_param = false
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute1: 'attribute1_invalid', attribute2: :required_and_inclusion, attribute4: :not_included }, errors)
    assert_equal({ attribute1: { list: '1,2' }, attribute2: { list: '1,2' }, attribute4: { list: '1,2' } }, error_options)
  end

  def test_attributes_with_errors
    test = TestValidation.new
    test.attribute2 = 1
    test.multi_error = '78'
    refute test.valid?
    assert test.errors.to_h.keys.count == 1
    assert_equal({ multi_error: :data_type_mismatch }, test.errors.to_h)
  end
end
