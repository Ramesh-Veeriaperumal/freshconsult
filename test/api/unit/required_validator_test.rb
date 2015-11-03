require_relative '../unit_test_helper'

class RequiredValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :name, :id, :title
    validates :name, :title, required: true
    validates :id, required: { allow_nil: true, message: :required_and_numericality }
  end

  def test_attribute_not_defined
    test = TestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ name: :missing, title: :missing }, errors)
  end

  def test_attribute_blank
    test = TestValidation.new
    test.name = test.title = ''
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ name: :blank, title: :blank }, errors)
  end

  def test_disallow_nil
    test = TestValidation.new
    test.name = test.title = 'test'
    test.id = ''
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ id: :required_and_numericality }, errors)
  end

  def test_valid_values
    test = TestValidation.new
    test.name = test.title = 'test'
    test.id = '2'
    assert test.valid?
    assert test.errors.empty?
  end
end
