require_relative '../test_helper'

class DateTimeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :fr_due_by, :due_by
    validates :due_by, :fr_due_by, date_time: { allow_nil: true }
  end

  def test_valid_date_time
    date_time_validator = DateTimeValidator.new(allow_nil: true, attributes: [:fr_due_by, :due_by])
    test = TestValidation.new
    test.due_by = Time.zone.now.to_s
    test.fr_due_by = Time.zone.now.to_s
    date_time_validator.validate_each(test, :due_by, Time.zone.now.to_s)
    date_time_validator.validate_each(test, :fr_due_by, Time.zone.now.to_s)
    assert test.errors.empty?
  end

  def test_invalid_date_time
    date_time_validator = DateTimeValidator.new(allow_nil: true, attributes: [:fr_due_by, :due_by])
    test = TestValidation.new
    test.due_by = 'test'
    test.fr_due_by = Time.zone.now.to_s
    date_time_validator.validate_each(test, :due_by, 'test')
    date_time_validator.validate_each(test, :fr_due_by, Time.zone.now.to_s)
    refute test.errors.empty?
    refute test.errors.full_messages.include?('Fr due by is not a date')
    assert test.errors.full_messages.include?('Due by is not a date')
  end

  def test_valid_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: true, attributes: [:fr_due_by, :due_by])
    test = TestValidation.new
    test.due_by = nil
    date_time_validator.validate_each(test, :due_by, nil)
    assert test.errors.empty?
  end

  def test_invalid_empty_string_for_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: true, attributes: [:fr_due_by, :due_by])
    test = TestValidation.new
    test.due_by = ''
    date_time_validator.validate_each(test, :due_by, '')
    refute test.errors.empty?
    assert test.errors.full_messages.include?('Due by is not a date')
  end

  def test_invalid_allow_nil
    date_time_validator = DateTimeValidator.new(allow_nil: false, attributes: [:fr_due_by, :due_by])
    test = TestValidation.new
    date_time_validator.validate_each(test, :fr_due_by, nil)
    date_time_validator.validate_each(test, :due_by, nil)
    refute test.errors.empty?
    assert_equal ['Fr due by is not a date', 'Due by is not a date'], test.errors.full_messages
  end
end
