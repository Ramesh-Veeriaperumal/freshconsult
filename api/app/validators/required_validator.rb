# Overriding defualt validator to add custom message to presence validation.

class RequiredValidator < ActiveModel::Validations::PresenceValidator
  def validate(record)
    attributes.each do |attribute|
      value = record.read_attribute_for_validation(attribute)
      next if record.errors[attribute].present? || (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
      validate_each(record, attribute, value)
    end
  end

  def validate_each(record, attribute, value)
    # return if value is there or a falseclass
    return if present_or_false?(value)
    if record.instance_variable_defined?("@#{attribute}".to_sym)
      record.errors.add(attribute, :blank, options)
    else
      message = options[:message] || 'missing'
      record.errors.add(attribute, message, options)
    end
  end

  # check if value is present or false class
  def present_or_false?(value)
    value.present? || value.is_a?(FalseClass)
  end
end
