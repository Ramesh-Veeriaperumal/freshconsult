require_relative '../unit_test_helper'

class RequiredValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :name, :id, :title
    validates :name, :title, required: true
    validates :id, required: { allow_nil: true, message: :required_and_numericality }
  end

  def test_attribute_not_defined
    test = TestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ name: :missing_field, title: :missing_field, id: :required_and_numericality }, errors)
    assert_equal({ name: { code: :missing_field }, title: { code: :missing_field }, id: { code: :missing_field } }, error_options)
  end

  def test_attribute_blank
    test = TestValidation.new
    test.name = test.title = test.id = ''
    refute test.valid?
    errors = test.errors.to_h
    error_options = test.error_options.to_h
    assert_equal({ name: :blank, title: :blank, id: :required_and_numericality }, errors)
    assert_equal({ name: {}, title: {}, id: {} }, error_options)
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
