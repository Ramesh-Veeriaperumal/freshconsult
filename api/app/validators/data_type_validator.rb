class DataTypeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, values)
    unless allow_nil(values) || valid_type?(options[:rules], values)
      record.errors[attribute] << "is not a/an #{options[:rules]}"
    end
  end

  private

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end

    def valid_type?(type, value)
      value.is_a? type
    end
end
