require_relative '../unit_test_helper'

class CustomLengthValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2
    validates :attribute1, custom_length: { maximum: 10 }
    validates :attribute2, custom_length: { maximum: 10, minimum: 2, message: 'test' }
  end

  def test_allow_nil
    test = TestValidation.new
    test.attribute2 = nil
    assert test.valid?
    assert test.errors.empty?
  end

  def test_attribute_not_responding_to_length
    test = TestValidation.new
    test.attribute2 = true
    assert test.valid?
    assert test.errors.empty?
  end

  def test_default_error_message
    test = TestValidation.new
    test.attribute2 = [1] * 11
    refute test.valid?
    assert_equal(['Attribute2 test'], test.errors.full_messages)
    assert_equal({ attribute2: { max_count: 10, current_count: 11, entities: :characters } }, test.error_options)

    test = TestValidation.new
    test.attribute2 = [1]
    refute test.valid?
    assert_equal(['Attribute2 test'], test.errors.full_messages)
    assert_equal({ attribute2: { max_count: 10, current_count: 1, entities: :characters } }, test.error_options)
  end

  def test_custom_error_message
    test = TestValidation.new
    test.attribute1 = [1] * 11
    refute test.valid?
    assert_equal(['Attribute1 too_long'], test.errors.full_messages)
    assert_equal({ attribute1: { max_count: 10, current_count: 11, entities: :characters } }, test.error_options)
  end

  def test_valid
    test = TestValidation.new
    test.attribute1 = [1] * 10
    test.attribute2 = '0' * 10
    assert test.valid?
    assert test.errors.empty?
  end
end
