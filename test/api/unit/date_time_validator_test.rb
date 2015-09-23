require_relative '../unit_test_helper'

class DateTimeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :fr_due_by, :due_by, :due_by_1, :error_options
    validates :due_by, :fr_due_by, date_time: { allow_nil: true }
    validates :due_by_1, date_time: { allow_nil: false }
  end

  def test_valid_date_time
    test = TestValidation.new
    test.due_by = Time.zone.now.to_s
    test.due_by_1 = Time.zone.now.to_s
    test.fr_due_by = Time.zone.now.to_s
    test.valid?
    assert test.errors.empty?
  end

  def test_invalid_date_time
    test = TestValidation.new
    test.due_by = 'test'
    test.fr_due_by = Time.zone.now.to_s
    test.due_by_1 = Time.zone.now.to_s
    test.valid?
    refute test.errors.empty?
    refute test.errors.full_messages.include?('Fr due by data_type_mismatch')
    assert test.errors.full_messages.include?('Due by data_type_mismatch')
  end

  def test_valid_allow_nil
    test = TestValidation.new
    test.due_by_1 = Time.zone.now.to_s
    test.due_by = nil
    test.valid?
    assert test.errors.empty?
  end

  def test_invalid_empty_string_for_allow_nil
    test = TestValidation.new
    test.due_by_1 = Time.zone.now.to_s
    test.due_by = ''
    test.valid?
    refute test.errors.empty?
    assert test.errors.full_messages.include?('Due by data_type_mismatch')
  end

  def test_invalid_allow_nil
    test = TestValidation.new
    test.valid?
    refute test.errors.empty?
    assert_equal ['Due by 1 data_type_mismatch'], test.errors.full_messages
  end
end
