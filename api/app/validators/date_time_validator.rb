class DateTimeValidator < ActiveModel::EachValidator
  ISO_DATE_DELIMITER     = 'T'
  TIME_EXCEPTION_MSG     = 'invalid_sec_or_zone'
  UNHANDLED_HOUR_VALUE   = '24'
  UNHANDLED_SECOND_VALUE = ':60'
  ZONE_PLUS_PREFIX       = '+'
  ZONE_MINUS_PREFIX      = '-'
  ISO_TIME_DELIMITER     = ':'
  FORMAT_EXCEPTION_MSG   = 'invalid_format'
  DATE_FORMAT            = 'yyyy-mm-dd'
  DATE_TIME_FORMAT       = 'yyyy-mm-ddThh:mm:ss±hh:mm'
  DATE_TIME_REGEX        = /^\d{4}-\d{2}-\d{2}/
  DATE_REGEX             = /^\d{4}-\d{2}-\d{2}$/

  def validate_each(record, attribute, values)
    return if record.errors[attribute].present?
    unless parse_time(values)
      message = options[:message] || get_message
      record.errors[attribute] << message
    end
  end

  def parse_time(value)
    # We will accept dates only only in the iso8601 format.This is to avoid cases were other formats may behave unexpectedly.
    # iso8601 expects date to follow the yyyy-mm-ddThh:mm:ss+dddd format, but it does not raise error, if say for "2000"
    # parse is more strict, but it accepts a wide variety of formats say, 3rd Feb 2001 04:05:06 PM
    # Hence we are using both, but still both of them do not handle seconds: 60, hours: 24 and invalid time zones, hence manipulation is done.
    # yyyy-mm-dd, yyyy-mm-ddThh:mm, yyyy-mm-ddThh:mm:ss, yyyy-mm-ddThh:mm:ssZ, yyyy-mm-ddThh:mm:ssz,
    # yyyy-mm-ddThh:mm:ss+hh, yyyy-mm-ddThh:mm:ss-hh, yyyy-mm-ddThh:mm:ss+hhmm, yyyy-mm-ddThh:mm:ss-hhmm
    # yyyy-mm-ddThh:mm:ss+hh:mm, yyyy-mm-ddThh:mm:ss-hh:mm
    DateTime.iso8601(value) && DateTime.parse(value) && iso8601_format(value)
    parse_sec_hour_and_zone(get_time_and_zone(value)) if time_info?(value) # avoid extra call if only date is present
    return true
    rescue => e
      Rails.logger.error("API Parse Time Error Value: #{value} Exception: #{e.class} Exception Message: #{e.message}")
      return false
  end

  private

    def get_message
      options[:only_date] ? :invalid_date : :invalid_date_time
    end

    def iso8601_format(value)
      fail(ArgumentError, FORMAT_EXCEPTION_MSG) unless value =~ date_time_regex_for_value
      true
    end

    def date_time_regex_for_value
      options[:only_date] ? DATE_REGEX : DATE_TIME_REGEX
    end

    def get_time_and_zone(value)
      value.split(ISO_DATE_DELIMITER).last
    end

    def time_info?(value)
      !options[:only_date] && value.include?(ISO_DATE_DELIMITER)
    end

    def parse_sec_hour_and_zone(tz_value) # time_and_zone_value
      fail(ArgumentError, TIME_EXCEPTION_MSG) unless valid_time(tz_value) && valid_zone(tz_value)
    end

    def valid_time(tz_value)
      # only seconds: 60 and hour: 24 needs to be handled here, as all other invalid values would be caught in parse.
      valid_sec(tz_value) && valid_hour(tz_value)
    end

    def valid_sec(tz_value)
      tz_value.exclude?(UNHANDLED_SECOND_VALUE) # :60
    end

    def valid_hour(tz_value)
      tz_value.split(ISO_TIME_DELIMITER).first != UNHANDLED_HOUR_VALUE # if : is absent and T is present parse would have failed.
    end

    def valid_zone(tz_value)
      if tz_value.include?(ZONE_PLUS_PREFIX)
        zone = tz_value.split(ZONE_PLUS_PREFIX).last
      elsif tz_value.include?(ZONE_MINUS_PREFIX)
        zone = tz_value.split(ZONE_MINUS_PREFIX).last
      end
      zone.nil? || validate_zone(zone)
    end

    def validate_zone(zone)
      # zone has to be in format +hhmm or -hhmm | +hh:mm or -hh:mm | +hh or -hh
      hh = zone[0..1]
      mm = zone[-1..-2] if zone.size != 2
      hh.to_i.between?(0, 23) && mm.to_i.between?(0, 59)
    end
end
