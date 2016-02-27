# Overriding default validator to add custom message to inclusion validation.

class CustomFormatValidator < ApiValidator

  def message
    :invalid_format
  end

  def invalid?
    regexp = call_block(options[:with])
    value !~ regexp
  end

  def error_options
    {code: :missing_field} if required_attribute_not_defined?
  end
end
