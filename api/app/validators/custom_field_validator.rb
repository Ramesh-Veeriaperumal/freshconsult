class CustomFieldValidator < ActiveModel::EachValidator
  def validate_each(record, _attribute, values)
    unless allow_nil(values)
      custom_fields = @validatable_custom_fields.respond_to?(:call) ? @validatable_custom_fields.call : @validatable_custom_fields
      custom_fields.each do |custom_field|
        method = "validate_format_of_#{custom_field.field_type}"
        if respond_to?(method, true)
          record.class.send(:attr_accessor, custom_field.name)
          record.instance_variable_set("@#{custom_field.name}", values[custom_field.name])
          send(method, record, custom_field.name.to_sym, values[custom_field.name]) if values[custom_field.name].present?
        else
          warn :"Validation Method #{method} is not present for the #{custom_field.field_type} - #{custom_field.inspect}"
        end
      end
    end
  end

  def check_validity!
    @validatable_custom_fields = options[:validatable_custom_fields] || []
    @nested_field_choices = options[:nested_field_choices] || {}
    @drop_down_choices = options[:drop_down_choices] || {}
  end

  private

    def validate_format_of_custom_text(_record, _field_name, _value)
    end

    def validate_format_of_custom_paragraph(_record, _field_name, _value)
    end

    def validate_format_of_custom_number(record, field_name, value)
      ActiveModel::Validations::NumericalityValidator.new(options.merge(attributes: field_name, only_integer: true)).validate_each(record, field_name, value)
    end

    def validate_format_of_custom_checkbox(record, field_name, value)
      CustomInclusionValidator.new(options.merge(attributes: field_name, in: ApiConstants::BOOLEAN_VALUES)).validate_each(record, field_name, value)
    end

    def validate_format_of_custom_decimal(record, field_name, value)
      ActiveModel::Validations::NumericalityValidator.new(options.merge(attributes: field_name)).validate_each(record, field_name, value)
    end

    def validate_format_of_nested_field(_record, _field_name, _value)
      # choices = @nested_field_choices
    end

    def validate_format_of_custom_dropdown(record, field_name, value)
      choices = @drop_down_choices.respond_to?(:call) ? @drop_down_choices.call : @drop_down_choices
      CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices[field_name])).validate_each(record, field_name, value)
    end

    def validate_format_of_custom_url(record, field_name, value)
      record.errors.add(field_name, 'is not a url') unless value[field_name.to_s] =~ URI.regexp
    end

    def validate_format_of_custom_date(record, field_name, value)
      DateTimeValidator.new(options.merge(attributes: field_name, allow_nil: true)).validate_each(record, field_name, value)
    end

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end
end
