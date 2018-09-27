module Freshquery
  class FqValidator < ActiveModel::EachValidator
    attr_reader :mapping, :helper, :options

    def validate(record)
      @mapping = record.mapping.to_hash
      @helper = record.mapping.fqhelper
      invalid_fields = record.request_params.keys - @mapping.keys
      if invalid_fields.present?
        invalid_fields.map { |v| record.errors[v] = :invalid_field }
      else
        record.request_params.each_pair do |key, values|
          @options = { attributes: key.to_sym }
          validate_each(record, key, @mapping[key], values)
        end
      end
    end

    def validate_each(record, key, options, values)
      method = method_name(options)
      safe_send(method, record, key, values) if method
    end

    def method_name(options)
      if options[:choices]
        @options[:in] = options[:choices].is_a?(Array) ? options[:choices] : @helper.safe_send(options[:choices])
        return 'validate_custom_dropdown_array'
      elsif options[:regex]
        @options[:with] = @helper.safe_send(options[:regex])
        return 'validate_custom_format_array'
      elsif options[:type]
        if options[:type] == 'positive_integer'
          @options[:only_integer] = true
          @options[:greater_than] = 0
          return 'validate_custom_number_array'
        elsif options[:type] == 'integer'
          @options[:only_integer] = true
          return 'validate_custom_number_array'
        elsif options[:type] == 'date'
          @options[:only_date] = true
          return 'validate_custom_date_array'
        elsif options[:type] == 'date_time'
          return 'validate_custom_date_array'
        elsif options[:type] == 'boolean'
          @options[:rules] = 'boolean'
          @options[:force_allow_string] = true
          return 'validate_custom_boolean_array'
        end
      end
    end

    def validate_custom_dropdown_array(record, attribute, values)
      validator = Freshquery::Validators::CustomInclusionValidator.new(@options)
      values.each do |value|
        validator.validate_value(record, value)
        return if record.errors[attribute].present?
      end
    end

    def validate_custom_number_array(record, attribute, values)
      validator = Freshquery::Validators::CustomNumericalityValidator.new(@options)
      values.each do |value|
        validator.validate_value(record, value)
        return if record.errors[attribute].present?
      end
    end

    def validate_custom_date_array(record, attribute, values)
      validator = Freshquery::Validators::DateTimeValidator.new(@options)
      values.each do |value|
        validator.validate_value(record, value)
        return if record.errors[attribute].present?
      end
    end

    def validate_custom_boolean_array(record, attribute, values)
      validator = Freshquery::Validators::BooleanValidator.new(@options)
      values.each do |value|
        validator.validate_value(record, value)
        return if record.errors[attribute].present?
      end
    end

    def validate_custom_format_array(record, attribute, values)
      validator = Freshquery::Validators::CustomFormatValidator.new(@options)
      values.each do |value|
        validator.validate_value(record, value)
        return if record.errors[attribute].present?
      end
    end
  end
end
