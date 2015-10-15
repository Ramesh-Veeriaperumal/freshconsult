# Check if value is not present.

class CustomAbsenceValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    message = options[:message] || 'present'
    record.errors.add(attribute, message) if record.instance_variable_defined?("@#{attribute}".to_sym)
  end
end