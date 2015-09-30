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
    test.due_by = Time.zone.now.iso8601
    test.fr_due_by = Time.zone.now.iso8601
    test.due_by_1 = Time.zone.now.iso8601
    test.valid?
    assert test.errors.empty?
  end

  def test_invalid_date_time
    test = TestValidation.new
    test.due_by = 'test'
    test.fr_due_by = Time.zone.now.iso8601
    test.valid?
    refute test.errors.empty?
    refute test.errors.full_messages.include?('Fr due by data_type_mismatch')
    assert test.errors.full_messages.include?('Due by data_type_mismatch')
  end

  def test_valid_allow_nil
    test = TestValidation.new
    test.due_by_1 = Time.zone.now.iso8601
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

  class TestFormat
    include ActiveModel::Validations
    ATTRIBUTES = :attr0, :attr1, :attr2, :attr3, :attr4, :attr5, :attr6, :attr7, :attr8, :attr9, :attr10,
                 :attr11, :attr12, :attr13, :attr14, :attr15, :attr16, :attr17, :attr18, :attr19, :attr20, :attr21,
                 :attr22, :attr23, :attr24, :attr25, :attr26, :attr27, :attr28, :attr29

    attr_accessor(*ATTRIBUTES, :error_options)

    validates(*ATTRIBUTES, date_time: true)
  end

  def test_invalid_format
    date_time_validator = DateTimeValidator.new(attributes: TestFormat::ATTRIBUTES)
    test = TestFormat.new
    values = ['2000', # invalid_length_only_year
              '2000-09', # invalid_length_only_year_and_month
              '2000-09-30', # valid_only_date
              '2-09-31', # invalid_year_length
              '2000-9-31', # invalid_month_length
              '2000-09-1', # invalid_date_length
              '1992-13-03', # invalid_month_value
              '2009-02-29', # leap_year_invalid_date
              '2008-02-29', # leap_year_valid_date
              '2009-02-28T', # invalid_length_with_T
              '2009-02-28T03', # invalid_length_with_date_and_only_hour
              '2009-02-28T03:00', # valid_length_with_date_and_only_hour_and_minutes
              '2009-02-28T03:50:50', # valid_date_with_time
              '2009-02-28T03:60:50', # invalid_minutes
              '2009-02-28T03:59:60', # invalid_seconds
              '2009-02-28T03:59:59+2300', # valid_timezone_positive
              '2009-02-28T03:59:59-2300', # valid_timezone_negative
              '2009-02-28T03:59:59Z', # valid_timezone_utc
              '2009-02-28T03:59:59z', # valid_timezone_utc
              '2009-02-28T03:59:59+2401', # out_of_bounds_timezone_positive
              '2009-02-28T03:59:59-2401', # out_of_bounds_timezone_negative
              '2009-02-28T03:59:59-240x', # invalid_time_zone_format
              '3rd Feb 2001 04:05:06 PM', # parseable_but_unaccepted_format
              '2009-02-28T24:00:00', # invalid_hours
              '2009-02-28T23:00:00-23:59', # valid_hours_and_minutes_time_zone
              '2009-02-28T23:00:00-23', # valid_only_hours_time_zone
              '2009-02-28T23:00:00--2359', # invalid_time_zone_format
              '2009-02-28T24:00:00++2359', # invalid_time_zone_format
              '2009-02-28T24:00:00+2399', # invalid_minutes_in_time_zone
              '2009-02-28T24:00:00+2400', # invalid_hours_in_time_zone
             ]

    values.each_with_index { |value, i| date_time_validator.validate_each(test, "attr#{i}", value) }
    errors = ['Attr0 data_type_mismatch',
              'Attr1 data_type_mismatch',
              'Attr3 data_type_mismatch',
              'Attr4 data_type_mismatch',
              'Attr5 data_type_mismatch',
              'Attr6 data_type_mismatch',
              'Attr7 data_type_mismatch',
              'Attr9 data_type_mismatch',
              'Attr10 data_type_mismatch',
              'Attr13 data_type_mismatch',
              'Attr14 data_type_mismatch',
              'Attr19 data_type_mismatch',
              'Attr20 data_type_mismatch',
              'Attr21 data_type_mismatch',
              'Attr22 data_type_mismatch',
              'Attr23 data_type_mismatch',
              'Attr26 data_type_mismatch',
              'Attr27 data_type_mismatch',
              'Attr28 data_type_mismatch',
              'Attr29 data_type_mismatch']

    assert_equal errors, test.errors.full_messages
  end
end
