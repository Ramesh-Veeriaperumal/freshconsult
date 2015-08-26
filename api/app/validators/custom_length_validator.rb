# Overriding defualt validator to strip values in length validation.

class CustomLengthValidator < ActiveModel::Validations::LengthValidator
  def validate_each(record, attribute, value)
    value = value.respond_to?(:strip) ? value.strip : value
    super(record, attribute, value)
  end
end
