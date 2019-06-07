class ExceededLimitValidator < RequiredValidator
  private

    def invalid?
      return true if super
      return record.child_levels.map(&:column_name).reject(&:blank?).count < 2 if record.nested_field?

      false
    end

    def record_error
      attribute_name = options[:error_label] || attribute
      record.errors[attribute_name] << (options[:message] || message)
      record.error_options[attribute_name] = custom_error_options.merge!(base_error_options)
    end

    def error_code
      :exceeded_limit unless attribute_defined?
    end

    def custom_error_options
      { field_type: record.field_type }
    end

    def message
      attribute_defined? ? :blank : :exceeded_limit
    end
end
