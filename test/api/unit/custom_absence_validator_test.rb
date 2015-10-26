require_relative '../unit_test_helper'

class CustomAbsenceValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :name, :id
    validates :name, custom_absence: true
    validates :id, custom_absence: { allow_nil: true, message: 'required_and_numericality' }
  end

  def test_attribute_defined
    test = TestValidation.new
    test.name = 'hjhj'
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ name: 'present' }, errors)
  end

  def test_attribute_not_defined
    test = TestValidation.new
    assert test.valid?
    assert test.errors.empty?
  end

  def test_allow_nil
    test = TestValidation.new
    test.id = nil
    assert test.valid?
    assert test.errors.empty?
  end

  def test_disallow_nil
    test = TestValidation.new
    test.name = nil
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ name: 'present' }, errors)
  end

  def test_custom_message
    test = TestValidation.new
    test.id = 'nnn'
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ id: 'required_and_numericality' }, errors)
  end
end
