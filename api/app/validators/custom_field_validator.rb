class CustomFieldValidator < ActiveModel::EachValidator
  ATTRS = [:current_field, :parent, :is_required, :required_attribute, :closure_status, :custom_fields, :current_field_defined, :nested_fields, :attribute, :section_field_mapping]
  attr_accessor(*ATTRS)
  NAME_MAPPING = { 'ticket_type' => 'type' }.freeze

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
        @is_required = required_field?(record, values) # find if the field is required
        @current_field_defined = key_exists?(values, field_name) # check if the field is defined for required validator
        next unless validate?(record, field_name, values) # check if it can be validated
        record.class.send(:attr_accessor, field_name)
        record.instance_variable_set("@#{field_name}", value) if @current_field_defined
        absence_validator_check(record, field_name, values)
        validate_each(record, field_name, value) if record.errors[field_name].blank?
      end
    end
  end

  def validate_each(record, attribute, _values)
    method = method_name
    if respond_to?(method, true)
      send(method, record, attribute)
    else
      warn :"Validation Method #{method} is not present for the #{current_field.field_type} - #{current_field.inspect}"
    end
  end

  private

    # Required validator for string field based on condition
    def validate_custom_text(record, field_name)
      string_options = construct_options(ignore_string: :allow_string_param, attributes: field_name, rules: String, required: @is_required)
      DataTypeValidator.new(string_options).validate(record)
      CustomLengthValidator.new(options.merge(attributes: field_name, maximum: ApiConstants::MAX_LENGTH_STRING)).validate(record)
    end

    # Required validator for string field based on condition
    def validate_custom_paragraph(record, field_name)
      string_options = construct_options(ignore_string: :allow_string_param, attributes: field_name, rules: String, required: @is_required)
      DataTypeValidator.new(string_options).validate(record)
    end

    # Numericality validator for number field
    def validate_custom_number(record, field_name)
      numericality_options = construct_options(ignore_string: :allow_string_param, only_integer: true, attributes: field_name, allow_nil: !@is_required, required: @is_required)
      CustomNumericalityValidator.new(numericality_options).validate(record)
    end

    # Datatype validator for boolean field
    def validate_custom_checkbox(record, field_name)
      boolean_options = construct_options(ignore_string: :allow_string_param, attributes: field_name, rules: 'Boolean', required: @is_required)
      DataTypeValidator.new(boolean_options).validate(record)
    end

    # Numericality validator for decimal field
    def validate_custom_decimal(record, field_name)
      numericality_options = construct_options(force_allow_string: true, attributes: field_name, allow_nil: !@is_required, required: @is_required)
      CustomNumericalityValidator.new(numericality_options).validate(record)
    end

    # Inclusion validator for nested field level 0
    def validate_nested_field_level_0(record, field_name)
      choices = get_choices(record, field_name, nil, nil, 0)
      CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices, allow_nil: !@is_required,  required: @is_required)).validate(record)
    end

    # Inclusion validator for nested field level 2
    # will not be validated if parent value (i.e., level 0 value) is nil
    def validate_nested_field_level_2(record, field_name)
      return unless @parent[:value]
      choices = get_choices(record, @parent[:name], @parent[:value], nil, 2)
      unless choices.nil?
        CustomInclusionValidator.new(options.merge(attributes: field_name, in: choices, allow_nil: !@is_required,  required: @is_required)).validate(record)
      end
    end

    # Inclusion validator for nested field level 3
    # will not be validated if parent value (i.e., level 1 value) or ancestor value (i.e., level 0 value) is nil
    def validate_nested_field_level_3(record, field_name)
      return unless @parent[:value] && @parent[:ancestor_value]
      choices = get_choices(record, @parent[:name], @parent[:value], @parent[:ancestor_value], 3)
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
      format_options = construct_options(attributes: field_name, with: ApiConstants::URL_REGEX,  allow_nil: !@is_required, required: @is_required, accepted: 'valid URL')
      CustomFormatValidator.new(format_options).validate(record)
    end

    def validate_custom_phone_number(record, field_name)
      string_options = construct_options(ignore_string: :allow_string_param, attributes: field_name, rules: String, required: @is_required)
      DataTypeValidator.new(string_options).validate(record)
      CustomLengthValidator.new(options.merge(attributes: field_name, maximum: ApiConstants::MAX_LENGTH_STRING)).validate(record)
    end

    # Date validator for date field
    def validate_custom_date(record, field_name)
      date_options = construct_options(attributes: field_name, allow_nil: !@is_required, only_date: true, required: @is_required)
      DateTimeValidator.new(date_options).validate(record)
    end

    def absence_validator_check(record, field_name, values)
      if section_field? && !section_parent_present?(record, values)
        parent = section_parent_list.keys.first
        message_options = { field: parent_name_mapping(parent.to_s), value: parent_value(parent, record, values) }
        CustomAbsenceValidator.new(attributes: field_name, message: :section_field_absence_check_error, message_options: message_options).validate(record)
      end
    end

    def assign_options(attribute)
      @attribute = attribute
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
    def required_field?(record, values)
      # Should we have to raise exception or warn if current_field doen't respond to required_attribute?
      is_required = (@required_attribute && @current_field.send(@required_attribute.to_sym)) || (@closure_status && @current_field.required_for_closure)
      is_required ||= @parent[:required] if @parent.present?
      is_required = section_parent_present?(record, values) if is_required && section_field?
      is_required
    end

    def section_parent_present?(record, values)
      section_parent_list.any? { |parent_field, value_mapping| value_mapping.include?(parent_value(parent_field, record, values)) }
    end

    def section_parent_list
      @section_field_mapping ||= proc_to_object(options[@attribute][:section_field_mapping]) || {}
      @section_field_mapping[@current_field.id] || {}
    end

    def parent_value(parent_field, record, values)
      (record.send(parent_field) || values.try(:[], parent_field))
    end

    def section_field?
      @current_field.respond_to?(:section_field?) && @current_field.section_field?
    end

    def parent_name_mapping(field)
      mapping = NAME_MAPPING[field] || custom_field?(field) || field
      mapping
    end

    def custom_field?(field)
      field.ends_with?("_#{Account.current.id}") ? TicketDecorator.display_name(mapping) : nil
    end

    # should allowed to be validated upon satisfying any of the below conditions
    # 1. required field
    # 2. value present?
    # 3. nested parent field with children not set
    def validate?(record, field_name, values)
      return false if section_field? && section_parent_has_errors?(record, values)
      @is_required || record.instance_variable_get("@#{field_name}_set") || (values.present? && !values.try(:[], field_name) && nested_field? && !children_set_or_blank?(record, field_name, values))
    end

    def section_parent_has_errors?(record, values)
      section_parent_list.all? { |parent_field, value_mapping| record.errors[parent_field].present? || parent_value(parent_field, record, values).nil? }
    end

    def key_exists?(values, key)
      values.try(:key?, key).present?
    end

    # Parent field should be set if children value is set in case of nested fields. otherwise error.
    def children_set_or_blank?(record, field_name, values)
      children = @custom_fields.select { |x| x.parent_id == @current_field.id || (x.level == 3 && x.parent_id == @current_field.parent_id && x.id != @current_field.id) }
      children.each do |child|
        next if values[child.name].blank?
        record.errors[field_name] << :conditional_not_blank
        (record.error_options ||= {}).merge!(field_name => { child: TicketDecorator.display_name(child.name) }) # we are explicitly calling decorator here, instead of handling this in the controller, in order to avoid unnecessary looping across all ticket fields.
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
    def construct_options(custom_options)
      options.merge(custom_options)
    end

    # Get choices based on level, field name & parent value for nested fields
    def get_choices(record, field_name, parent_value, ancestor_value, level = 0)
      @nested_fields ||= proc_to_object(@nested_field_choices, record) if @nested_field_choices.present?
      case level
      when 0
        return @nested_fields[field_name.to_s].try(:keys)
      when 2
        return @nested_fields[field_name.to_s].try(:[], parent_value).try(:keys)
      when 3
        return @nested_fields[field_name.to_s].try(:[], ancestor_value).try(:[], parent_value)
      end
    end
end
