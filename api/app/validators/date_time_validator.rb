class DateTimeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, values)
    unless allow_nil(values) || self.class.parse_time(values)
      record.errors[attribute] << 'data_type_mismatch'
      (record.error_options ||= {}).merge!(attribute => { data_type: 'date' })
    end
  end

  def self.parse_time(value)
    Time.zone.parse(value) # This will raise exception only if value is not a string, for values it cannot parse it returns nil.
    rescue
      return false
  end

  private

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end
end
