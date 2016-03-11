class StringRejectionValidator < ApiValidator
  private

    def invalid?
      field_value = formatted_value
      options[:excluded_chars].any? { |x| field_value.include?(x) } if field_value
    end

    def formatted_value
      case value
      when Array
        value.join
      when String
        value
      end
    end

    def message
      :special_chars_present
    end

    def custom_error_options
      { chars: options[:excluded_chars].join('\',\'') }
    end
end
