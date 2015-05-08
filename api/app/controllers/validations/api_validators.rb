module ApiValidators
  class DateTimeValidator < ActiveModel::Validator
  	
    def validate(record)
      options[:fields].each do |field|
        record.errors[field.to_sym] << "is not a date" unless allow_nil(record.send(field)) || parse_time(record.send(field))
      end
    end

    private
    def parse_time value
      begin 
        Time.zone.parse(value)
      rescue Exception => e
        return false
      end
    end

    def allow_nil value
      options[:allow_nil] == true && value.blank?
    end
  end
end