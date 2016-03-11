class CustomLengthValidator < ApiValidator
  private

    def invalid?
      value_length = value.length
      # CHECKS    = { :is => :==, :minimum => :>=, :maximum => :<= }.freeze
      ActiveModel::Validations::LengthValidator::CHECKS.each do |key, operator|
        next unless expected_value = options[key]
        return true unless value_length.send(operator, expected_value)
      end
      false
    end

    def allow_nil?(_options)
      value.nil?
    end

    def message
      :too_long
    end

    def custom_error_options
      { max_count: options[:maximum], current_count: value.length, element_type: :characters }
    end

    def skip_validation?
      super || !value.respond_to?(:length)
    end
end
