# Check if value is not present.

class CustomAbsenceValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, _value)
    message = options[:message] || :present
    record.errors[attribute] << message if record.instance_variable_defined?("@#{attribute}".to_sym)
  end
end
