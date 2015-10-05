require_relative '../unit_test_helper'

class StringRejectionValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :attribute3, :error_options
    validates :attribute1, string_rejection: { excluded_chars: [','] }
    validates :attribute2, string_rejection: { excluded_chars: [',', 'junk', '!', '$'] }
    validates :attribute3, string_rejection: { excluded_chars: [6767] }

    def initialize(params_hash)
      params_hash.each { |k, v| instance_variable_set("@#{k}", v) }
    end
  end

  def test_attribute_string_invalid
    test = TestValidation.new(attribute1: 'test,hell')
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute1: 'special_chars_present' }, errors)
    assert_equal({ attribute1: { chars: ',' } }, error_options)
  end

  def test_attribute_array_invalid
    test = TestValidation.new(attribute2: ['%$,test', 'junk'])
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ attribute2: 'special_chars_present' }, errors)
    assert_equal({ attribute2: { chars: [',', 'junk', '!', '$'].join('\',\'') } }, error_options)
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
