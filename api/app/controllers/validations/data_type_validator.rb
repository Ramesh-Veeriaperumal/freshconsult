class DataTypeValidator < ActiveModel::Validator
  def validate(record)
    options[:rules].each_pair do |type, fields|
      fields.each do |field|
        record.errors[field.to_sym] << "is not a/an #{type}" unless allow_nil(record.send(field)) || valid_type?(type, record.send(field))
      end
    end
  end

  private

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end

    def valid_type?(type, value)
      value.is_a? Object.const_get(type) # type is a string. But is_a? expects class or module name. So Object.const_get?
    end
end
