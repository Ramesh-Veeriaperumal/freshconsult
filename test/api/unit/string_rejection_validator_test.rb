require_relative '../unit_test_helper'

class StringRejectionValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :attribute3

    validates :attribute2, data_type: { rules: Array, allow_nil: true }
    validates :attribute1, string_rejection: { excluded_chars: [','], allow_nil: true }
    validates :attribute2, string_rejection: { excluded_chars: [',', 'junk', '!', '$'], allow_nil: true }
    validates :attribute3, string_rejection: { excluded_chars: [6767], allow_nil: true }

    def initialize(params_hash)
      super
      params_hash.each { |k, v| instance_variable_set("@#{k}", v) }
    end
  end

  def test_attribute_string_invalid
    test = TestValidation.new(attribute1: 'test,hell')
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute1: :special_chars_present }, errors)
    assert_equal({ attribute1: { chars: ',' } }, error_options)
  end

  def test_attribute_array_invalid
    test = TestValidation.new(attribute2: ['%$,test', 'junk'])
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :special_chars_present }, errors)
    assert_equal({ attribute2: { chars: [',', 'junk', '!', '$'].join('\',\'') } }, error_options)
  end

  def test_attributes_with_error
    test = TestValidation.new(attribute2: '%$,test, junk')
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: :data_type_mismatch }, errors)
    assert_equal({ attribute2: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String} }, test.error_options)
    assert errors.count == 1
  end

  def test_attribute_string_valid
    test = TestValidation.new(attribute1: 'junkthings')
    assert test.valid?
  end

  def test_attribute_array_valid
    test = TestValidation.new(attribute2: ['hello', 'hell'])
    assert test.valid?
  end

  def test_attribute_other_data_type
    test = TestValidation.new(attribute3: 6767)
    assert test.valid?
  end

  def test_attribute_nil
    test = TestValidation.new(attribute2: nil, attribute1: nil, attribute3: nil)
    assert test.valid?
  end
end
