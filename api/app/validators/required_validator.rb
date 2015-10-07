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
    if record.instance_variable_defined?("@#{attribute}".to_sym)
      record.errors.add(attribute, :blank, options) if value.blank?
    else
      message = options[:message] || 'missing'
      record.errors.add(attribute, message, options)
    end
  end
end
