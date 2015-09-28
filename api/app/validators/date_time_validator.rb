class DateTimeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, values)
    unless self.class.parse_time(values)
      message = options[:message] || 'data_type_mismatch'
      record.errors[attribute] << message
      (record.error_options ||= {}).merge!(attribute => { data_type: 'date' })
    end
  end

  def self.parse_time(value)
    # Time.zone.parse will raise exception if value is not a string or out of range,
    # For values it cannot parse, it returns nil.
    Time.zone.parse(value)
    # https://robots.thoughtbot.com/rescue-standarderror-not-exception
    rescue StandardError => e
      Rails.logger.error("API Parse Time Error Value: #{value} Exception: #{e.class} Exception Message: #{e.message}")
      return false
  end
end
