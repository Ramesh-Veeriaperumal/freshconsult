require_relative '../unit_test_helper'

class DateTimeValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations

    attr_accessor :fr_due_by, :due_by, :due_by_1, :error_options, :multi_error

    validates :multi_error, data_type: { rules: Date, allow_nil: true }
    validates :due_by, :fr_due_by, :multi_error, date_time: { allow_nil: true }
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
    refute test.errors.full_messages.include?('Fr due by invalid_date_time')
    assert test.errors.full_messages.include?('Due by invalid_date_time')
  end

  def test_attributes_multiple_error
    test = TestValidation.new
    test.due_by_1 = Time.zone.now.iso8601
    test.multi_error = 'thy'
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({ multi_error: 'data_type_mismatch' }, test.errors.to_h)
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
    assert test.errors.full_messages.include?('Due by invalid_date_time')
  end

  def test_invalid_allow_nil
    test = TestValidation.new
    test.valid?
    refute test.errors.empty?
    assert_equal ['Due by 1 invalid_date_time'], test.errors.full_messages
  end

  class TestFormat
    include ActiveModel::Validations
    ATTRIBUTES = :attr0, :attr1, :attr2, :attr3, :attr4, :attr5, :attr6, :attr7, :attr8, :attr9, :attr10,
                 :attr11, :attr12, :attr13, :attr14, :attr15, :attr16, :attr17, :attr18, :attr19, :attr20, :attr21,
                 :attr22, :attr23, :attr24, :attr25, :attr26, :attr27, :attr28, :attr29, :attr30, :attr31, :attr32,
                 :attr33, :attr34

    attr_accessor(*ATTRIBUTES, :error_options)

    validates(*ATTRIBUTES, date_time: true)
  end

  def test_invalid_date_time_format
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
              '2015-280', # accepted by iso but invalid format 
              '2015-W4-3', # accepted by iso but invalid format 
              '20150909', # accepted by iso but invalid format 
              '2015-09-09T0909', # invalid without hyphen in time
              '2015-09-09T09:09+0530', # valid without second info
             ]

    values.each_with_index { |value, i| test.send("attr#{i}=", value) }
    refute test.valid?
    errors = ['Attr0 invalid_date_time',
              'Attr1 invalid_date_time',
              'Attr3 invalid_date_time',
              'Attr4 invalid_date_time',
              'Attr5 invalid_date_time',
              'Attr6 invalid_date_time',
              'Attr7 invalid_date_time',
              'Attr9 invalid_date_time',
              'Attr10 invalid_date_time',
              'Attr13 invalid_date_time',
              'Attr14 invalid_date_time',
              'Attr19 invalid_date_time',
              'Attr20 invalid_date_time',
              'Attr21 invalid_date_time',
              'Attr22 invalid_date_time',
              'Attr23 invalid_date_time',
              'Attr26 invalid_date_time',
              'Attr27 invalid_date_time',
              'Attr28 invalid_date_time',
              'Attr29 invalid_date_time',
              'Attr30 invalid_date_time',
              'Attr31 invalid_date_time',
              'Attr32 invalid_date_time',
              'Attr33 invalid_date_time'
              ]

    assert_equal errors, test.errors.full_messages
  end

  def test_date_comparison_with_time_zones
    zone = Time.zone
    Time.zone = "UTC"
    utc_time = Time.zone.now
    utc_time_string = utc_time.iso8601
    zone_time = (utc_time - 1.second).in_time_zone("Chennai")
    zone_time_string = zone_time.iso8601
    assert zone_time_string > utc_time_string # zone_time_string is greater than utc_time_string when string comparison is done.
    assert utc_time > zone_time_string # when one of the operands is a Time object AR compares time info with time zones properly
    assert utc_time > zone_time # When both operands are time objects AR compares time info with time zones properly
    Time.zone = zone
  end

  class TestDateFormat
    include ActiveModel::Validations
    ATTRIBUTES = :attr0, :attr1, :attr2, :attr3, :attr4, :attr5, :attr6, :attr7, :attr8, :attr9, :attr10,
                 :attr11, :attr12, :attr13, :attr14, :attr15, :attr16, :attr17, :attr18, :attr19, :attr20, :attr21,
                 :attr22, :attr23, :attr24, :attr25, :attr26, :attr27, :attr28, :attr29, :attr30, :attr31, :attr32,
                 :attr33, :attr34

    attr_accessor(*ATTRIBUTES, :error_options)

    validates(*ATTRIBUTES, date_time: {only_date: true})
  end

  def test_invalid_date_format
    date_time_validator = DateTimeValidator.new(attributes: TestDateFormat::ATTRIBUTES)
    test = TestDateFormat.new
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
              '2009-02-28T03:00', # valid_length_with_date_and_only_hour_and_minutes # but has time info so invalid
              '2009-02-28T03:50:50', # valid_date_with_time # but has time info so invalid
              '2009-02-28T03:60:50', # invalid_minutes
              '2009-02-28T03:59:60', # invalid_seconds
              '2009-02-28T03:59:59+2300', # valid_timezone_positive # but has time info so invalid
              '2009-02-28T03:59:59-2300', # valid_timezone_negative # but has time info so invalid
              '2009-02-28T03:59:59Z', # valid_timezone_utc # but has time info so invalid
              '2009-02-28T03:59:59z', # valid_timezone_utc # but has time info so invalid
              '2009-02-28T03:59:59+2401', # out_of_bounds_timezone_positive
              '2009-02-28T03:59:59-2401', # out_of_bounds_timezone_negative
              '2009-02-28T03:59:59-240x', # invalid_time_zone_format
              '3rd Feb 2001 04:05:06 PM', # parseable_but_unaccepted_format
              '2009-02-28T24:00:00', # invalid_hours
              '2009-02-28T23:00:00-23:59', # valid_hours_and_minutes_time_zone # but has time info so invalid
              '2009-02-28T23:00:00-23', # valid_only_hours_time_zone # but has time info so invalid
              '2009-02-28T23:00:00--2359', # invalid_time_zone_format
              '2009-02-28T24:00:00++2359', # invalid_time_zone_format
              '2009-02-28T24:00:00+2399', # invalid_minutes_in_time_zone
              '2009-02-28T24:00:00+2400', # invalid_hours_in_time_zone
              '2015-280', # accepted by iso but invalid format 
              '2015-W4-3', # accepted by iso but invalid format 
              '20150909', # accepted by iso but invalid format 
              '2015-09-09T0909', # invalid without hyphen in time
              '2015-09-09T09:09+0530', # valid without second info # but has time info so invalid
             ]

    values.each_with_index { |value, i| test.send("attr#{i}=", value) }
    refute test.valid?
    errors = ['Attr0 invalid_date',
              'Attr1 invalid_date',
              'Attr3 invalid_date',
              'Attr4 invalid_date',
              'Attr5 invalid_date',
              'Attr6 invalid_date',
              'Attr7 invalid_date',
              'Attr9 invalid_date',
              'Attr10 invalid_date',
              'Attr11 invalid_date',
              'Attr12 invalid_date',
              'Attr13 invalid_date',
              'Attr14 invalid_date',
              'Attr15 invalid_date',
              'Attr16 invalid_date',
              'Attr17 invalid_date',
              'Attr18 invalid_date',
              'Attr19 invalid_date',
              'Attr20 invalid_date',
              'Attr21 invalid_date',
              'Attr22 invalid_date',
              'Attr23 invalid_date',
              'Attr24 invalid_date',
              'Attr25 invalid_date',
              'Attr26 invalid_date',
              'Attr27 invalid_date',
              'Attr28 invalid_date',
              'Attr29 invalid_date',
              'Attr30 invalid_date',
              'Attr31 invalid_date',
              'Attr32 invalid_date',
              'Attr33 invalid_date',
              'Attr34 invalid_date',
              ]

    assert_equal errors, test.errors.full_messages
  end

end
