class CustomFieldValidator < ActiveModel::EachValidator
  ATTRS = [:current_field, :parent, :is_required, :required_attribute, :closure_status, :custom_fields, :current_field_defined, :nested_fields]
  attr_accessor(*ATTRS)

  def validate(record)
    attributes.each do |attribute|
      values = record.read_attribute_for_validation(attribute)
      next if record.errors[attribute].present? || (values.nil? && options[:allow_nil]) || (values.blank? && options[:allow_blank])
      reset_attr_accessors
      assign_options(attribute)

      # find if fields are required based on status
      @closure_status = proc_to_object(@required_based_on_status, record)

      # get all validatable custom fields
      @custom_fields = proc_to_object(@validatable_custom_fields, record)
      @custom_fields.each do |custom_field|
        @current_field = custom_field
        field_name = custom_field.name # assign field name
        value = values.try(:[], custom_field.name) # assign value
        @parent =  nested_field? && parent_exists? ? get_parent(values) : {} # get parent if nested_field for computing required
        @is_required = required_field? # find if the field is required
        @current_field_defined = key_exists?(values, field_name) # check if the field is defined for required validator
        next unless validate?(record, field_name, values) # check if it can be validated
        record.class.send(:attr_accessor, field_name)
        record.instance_variable_set("@#{field_name}", value) if @current_field_defined
        validate_each(record, field_name, value)
      end
    end
  end

  def validate_each(record, attribute, _values)
    method = method_name
    if respond_to?(method, true)
      send(method, record, attribute.to_sym)
    else
      warn :"Validation Method #{method} is not present for the #{current_field.field_type} - #{current_field.inspect}"
    end
  end

  # Required validator for string field based on condition
  def validate_custom_text(record, field_name)
    RequiredValidator.new(options.merge(attributes: field_name)).validate(record) if @is_required
    ActiveModel::Validations::LengthValidator.new(options.merge(attributes: field_name, maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long)).validate(record) if record.errors[field_name].blank?
  end

  # Required validator for string field based on condition
  def validate_custom_paragraph(record, field_name)
    RequiredValidator.new(options.merge(attributes: field_name)).validate(record) if @is_required
  end

  # Numericality validator for number field
  def validate_custom_number(record, field_name)
    numericality_options = construct_options({ ignore_string: :allow_string_param, attributes: field_name, allow_negative: true, only_integer: true, allow_nil: !@is_required }, :required_integer)
    CustomNumericalityValidator.new(numericality_options).validate(record)
  end

  # Datatype validator for boolean field
  def validate_custom_checkbox(record, field_name)
    boolean_options = construct_options({ ignore_string: :allow_string_param, attributes: field_name, rules: 'Boolean', required: @is_required }, :required_boolean)
    DataTypeValidator.new(boolean_options).validate(record)
  end

  # Numericality validator for decimal field
  def validate_custom_decimal(record, field_name)
    numericality_options = construct_options({ ignore_string: :allow_string_param, attributes: field_name, allow_nil: !@is_required }, 'required_number')
    ActiveModel::Validations::NumericalityValidator.new(numericality_options).validate(record)
  end

  # Inclusion validator for nested field level 0
  def validate_nested_field_level_0(record, field_name)
    choices = get_choices(record, field_name, nil, 0)
    CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices, allow_nil: !@is_required,  required: @is_required)).validate(record)
  end

  # Inclusion validator for nested field level 2
  # will not be validated if parent value (i.e., level 0 value) is nil
  def validate_nested_field_level_2(record, field_name)
    return unless @parent[:value]
    choices = get_choices(record, @parent[:name], @parent[:value], 2)
    unless choices.nil?
      CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices, allow_nil: !@is_required,  required: @is_required)).validate(record)
    end
  end

  # Inclusion validator for nested field level 3
  # will not be validated if parent value (i.e., level 1 value) or ancestor value (i.e., level 0 value) is nil
  def validate_nested_field_level_3(record, field_name)
    return unless @parent[:value] && @parent[:ancestor_value]
    choices = get_choices(record, @parent[:name], @parent[:value], 3)
    unless choices.nil?
      CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices, allow_nil: !@is_required,  required: @is_required)).validate(record)
    end
  end

  # Inclusion validator for dropdown field
  def validate_custom_dropdown(record, field_name)
    choices = proc_to_object(@drop_down_choices, record)
    CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices[field_name], allow_nil: !@is_required, required: @is_required)).validate(record)
  end

  # Format validator for url field
  def validate_custom_url(record, field_name)
    # REGEX is taken from jquery.validate.js
    format_options = construct_options({ attributes: field_name, with: ApiConstants::URL_REGEX,  allow_nil: !@is_required, message: 'invalid_format' }, 'required_format')
    ActiveModel::Validations::FormatValidator.new(format_options).validate(record)
  end

  def validate_custom_phone_number(record, field_name)
    RequiredValidator.new(options.merge(attributes: field_name)).validate(record) if @is_required
    ActiveModel::Validations::LengthValidator.new(options.merge(attributes: field_name, maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long)).validate(record) if record.errors[field_name].blank?
  end

  # Date validator for date field
  def validate_custom_date(record, field_name)
    date_options = construct_options({ attributes: field_name, allow_nil: !@is_required, only_date: true }, :required_date)
    DateTimeValidator.new(date_options).validate(record)
  end

  private

    def assign_options(attribute)
      @validatable_custom_fields = options[attribute][:validatable_custom_fields] || []
      @nested_field_choices = options[attribute][:nested_field_choices] || {}
      @drop_down_choices = options[attribute][:drop_down_choices] || {}
      @required_based_on_status = options[attribute][:required_based_on_status]
      @required_attribute = options[attribute][:required_attribute]
    end

    # http://www.blrice.net/blog/2013/11/07/rails-validator-classes-and-instance-vars/
    # Resetting attr_accessors since Validator class being instantiated only once.
    def reset_attr_accessors
      ATTRS.each { |var| instance_variable_set("@#{var}", nil) }
    end

    def proc_to_object(proc, record = nil)
      proc.respond_to?(:call) ? proc.call(record) : proc
    end

    # Get parent hash with name, ancestor_name, value , ancestor_value and required in case of nested_field
    def get_parent(values)
      ancestor = @custom_fields.detect { |x| x.id == @current_field.parent_id }
      parent = @current_field.level == 2 ? ancestor : @custom_fields.detect { |x| x.parent_id == @current_field.parent_id && x.level == 2 }
      parent && ancestor ? { name: ancestor.name, value: values.try(:[], parent.name), ancestor_value: values.try(:[], ancestor.name), required: (ancestor.required || (ancestor.required_for_closure && @closure_status)) } : {}
    end

    # required based on ticket field attribute or combination of status & ticket field attribute.
    def required_field?
      # Should we have to raise exception or warn if current_field doen't respond to required_attribute?
      is_required = @current_field.send(@required_attribute.to_sym) || (@closure_status && @current_field.required_for_closure)
      is_required ||= @parent[:required] if @parent.present?
      is_required
    end

    # should allowed to be validated upon satisfying any of the below conditions
    # 1. required field
    # 2. value present?
    # 3. nested parent field with children not set
    def validate?(record, field_name, values)
      @is_required || values.try(:[], field_name) || (values.present? && nested_field? && !children_set_or_blank?(record, field_name, values))
    end

    def key_exists?(values, key)
      values.try(:key?, key).present?
    end

    # Parent field should be set if children value is set in case of nested fields. otherwise error.
    def children_set_or_blank?(record, field_name, values)
      children = @custom_fields.select { |x| x.parent_id == @current_field.id || (x.level == 3 && x.parent_id == @current_field.parent_id) }
      children.each do |child|
        next if values[child.name].blank?
        record.errors[field_name.to_sym] << :conditional_not_blank
        (record.error_options ||= {}).merge!(field_name.to_sym => { child: child.name })
        return true
      end
      true
    end

    def method_name
      method = "validate_#{@current_field.field_type}"
      method += "_level_#{@current_field.level.to_i}" if nested_field?
      method.freeze
    end

    def nested_field?
      @current_field.field_type == 'nested_field'.freeze
    end

    def parent_exists?
      @current_field.parent_id.present?
    end

    # construct options hash for diff validators
    def construct_options(custom_options, required_message = :missing)
      options_hash = options.merge(custom_options)

      # custom message to be merged to give missing_field as code in error response if no field is defined & is required.
      options_hash.merge!(message: required_message) if @is_required && !@current_field_defined
      options_hash
    end

    # Get choices based on level, field name & parent value for nested fields
    def get_choices(record, field_name, parent_value, level = 0)
      @nested_fields ||= proc_to_object(@nested_field_choices, record) if @nested_field_choices.present?
      case level
      when 0
        return @nested_fields[:first_level_choices][field_name.to_s]
      when 2
        return @nested_fields[:second_level_choices][field_name.to_s].try(:[], parent_value)
      when 3
        return @nested_fields[:third_level_choices][field_name.to_s].try(:[], parent_value)
      end
    end
end
