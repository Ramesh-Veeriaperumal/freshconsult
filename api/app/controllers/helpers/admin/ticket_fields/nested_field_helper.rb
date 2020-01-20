module Admin::TicketFields::NestedFieldHelper
  include Admin::TicketFieldConstants

  def can_delete_nested_choice?
    # for choice controller, yet to write
  end

  def can_delete_nested_field?
    errors[:"#{TicketDecorator.display_name(tf[:name])}"] << :nested_field_child_delete_error unless tf[:parent_id].nil?
  end

  def nested_level_db_validation
    return if errors.present?

    child_lvls = record.dependent_fields
    helpdesk_nested_field = record.helpdesk_nested_ticket_fields_from_cache
    dependent_fields.each do |nested_level|
      # id is mandatory for 2nd level
      if nested_level[:level] == 2
        validate_level2_db_data(child_lvls, helpdesk_nested_field, nested_level)
      elsif nested_level[:level] == 3
        validate_level3_db_data(child_lvls, helpdesk_nested_field, nested_level)
      end
    end
  end

  def validate_level2_db_data(child_lvls, helpdesk_nested_field, nested_level)
    name = :"#{tf[:label] || label}[level#{nested_level[:level]}]"
    child_level = child_lvls.find { |x| x.id == nested_level[:id].to_i && x.level == nested_level[:level] }
    level_nested_field = helpdesk_nested_field.find { |nested_field| nested_field.level == DEPENDENT_FIELD_LEVELS[0] }
    # either data is corrupted in helpdesk_nested_field or wrong id for level2
    if child_level.blank? || level_nested_field.blank?
      missing_param_error(name, :id) if nested_level[:id].blank?
      absent_in_db_error(name, record.label, :id) if child_level.blank?
      return if errors.present?

      errors[name] << :ticket_field_data_corrupted_error if level_nested_field.blank?
    end
  end

  def validate_level3_db_data(child_lvls, helpdesk_nested_field, nested_level)
    name = :"#{tf[:label] || label}[level#{nested_level[:level]}]"
    child_level = child_lvls.find { |x| x.id == nested_level[:id].to_i && x.level == nested_level[:level] }
    level_nested_field = helpdesk_nested_field.find { |nested_field| nested_field.level == DEPENDENT_FIELD_LEVELS[1] }
    # either data is corrupted in helpdesk_nested_field or wrong id for level2
    if nested_level.key?(:id) && (child_level.blank? || level_nested_field.blank?)
      absent_in_db_error(name, record.label, :id) if child_level.blank?
      return if errors.present?

      errors[name] << :ticket_field_data_corrupted_error if level_nested_field.blank?
    end
    errors["dependent_fields[level3][id]".intern] << :missing_field if !nested_level.key?(:id) && level_nested_field.present?
  end

  def check_dependent_field_level_uniqueness(nested_levels)
    max_level_count = nested_levels.group_by { |x| x[:level] }.each_with_object({}) { |data, map| map[data[0]] = data[1].length }.values.max
    errors[:level] << :duplicate_level if max_level_count > 1
  end

  def delete_level_validation(dependent_fields)
    dependent_fields.each do |nested_level|
      next unless nested_level.key?(:deleted)

      # trying to delete second level
      errors[:level2] << :level_two_mandatory_error if nested_level[:level] == DEPENDENT_FIELD_LEVELS[0]
      errors["level#{nested_level[:level]}[:deleted]".intern] << :invalid_field if !nested_level.key?(:id) && nested_level.key?(:deleted)
    end
  end

  def mandatory_level_validation(dependent_fields)
    missing_param_error(:dependent_fields, :level2) unless dependent_fields.any? { |data| data[:level] == DEPENDENT_FIELD_LEVELS[0]}
  end

  def level_value_validation(dependent_fields)
    errors[name.to_s] << :dependent_field_level_error if dependent_fields.any? { |nested_level| DEPENDENT_FIELD_LEVELS.exclude?(nested_level[:level]) }
  end

  def mandatory_dependent_field_params_check(dependent_fields)
    dependent_fields.each do |nested_level|
      nested_keys = nested_level.dup.symbolize_keys.keys
      mandatory_params = nested_level.key?(:id) ? UPDATE_DEPENDENT_FIELD_PARAMS : DEPENDENT_FIELD_MANDATORY_PARAMS
      missing_params = mandatory_params - nested_keys
      missing_param_error(:dependent_fields, missing_params.join(', ')) if missing_params.present?
      errors["dependent_fields[:id]".intern] << :invalid_field if create_action? && nested_level.key?(:id)
    end
  end

  def validate_dependent_field_data_type(dependent_fields)
    dependent_fields.each do |nested_field|
      (invalid_data_type(:dependent_fields, :invalid, :json) && break) if nested_field.blank? || !nested_field.is_a?(Hash)
      nested_field.each_pair do |key, value|
        key = key.to_s.intern
        return unexpected_value_for_attribute(:"dependent_fields[#{key}]", key) if ALLOWED_DEPENDENT_FIELD_PARAMS.exclude?(key)

        valid_data_type?(:dependent_fields, key, value, DEPENDENT_FIELD_PARAMS_WITH_TYPE[key]) if errors.blank?
        validate_presence_of_data?(:dependent_fields, key, value) if errors.blank?
      end
    end
  end

  def nested_level_param_validation
    validate_dependent_field_data_type(dependent_fields) if errors.blank?
    mandatory_dependent_field_params_check(dependent_fields) if errors.blank?
    check_dependent_field_level_uniqueness(dependent_fields) if errors.blank?
    mandatory_level_validation(dependent_fields) if errors.blank? && create_action?
    delete_level_validation(dependent_fields) if errors.blank?
    level_value_validation(dependent_fields) if errors.blank?
  end
end
