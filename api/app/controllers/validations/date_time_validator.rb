class DateTimeValidator < ActiveModel::Validator
  def validate(record)
    options[:fields].each do |field|
      record.errors[field.to_sym] << 'is not a date' unless allow_nil(record.send(field)) || parse_time(record.send(field))
    end
  end

  private

    def parse_time(value)
      Time.zone.parse(value) # This will raise exception only if value is not a string, for values it cannot parse it returns nil.
      rescue
        return false
    end

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end
end
