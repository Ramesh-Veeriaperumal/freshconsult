# Overriding default validator to add custom message to inclusion validation.

class CustomFormatValidator < ApiValidator
  private

    def message
      :invalid_format
    end

    def invalid?
      regexp = call_block(options[:with])
      value !~ regexp
    end

    def error_code
      :missing_field if required_attribute_not_defined?
    end

    def custom_error_options
      { accepted: options[:accepted] || 'accepted #{attribute}' }
    end
end
