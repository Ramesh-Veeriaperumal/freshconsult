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

    child_lvls = record.child_levels
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
    level = child_lvls.find { |x| x.id == nested_level[:id].to_i && x.level == nested_level[:level] }
    level_nested_field = helpdesk_nested_field.first
    # either data is corrupted in helpdesk_nested_field or wrong id for level2
    if level.blank? || (level_nested_field.blank? || level_nested_field.level != 2)
      missing_param_error(name, :id) if nested_level[:id].blank?
      absent_in_db_error(name, record.label, :id) if level.present?
      errors[name] << :ticket_field_data_corrupted_error if level_nested_field.blank? || level_nested_field.level != 2
    end
  end

  def validate_level3_db_data(child_lvls, helpdesk_nested_field, nested_level)
    name = :"#{tf[:label] || label}[level#{nested_level[:level]}]"
    level = child_lvls.find { |x| x.id == nested_level[:id].to_i && x.level == nested_level[:level] }
    level_nested_field = helpdesk_nested_field.last
    # either data is corrupted in helpdesk_nested_field or wrong id for level2
    if (level.blank? && child_lvls.count > 1) || (level_nested_field.blank? || level_nested_field.level != 3)
      missing_param_error(name, :id) if nested_level[:id].blank?
      absent_in_db_error(name, record.label, :id) if level.blank?
      errors[name] << :ticket_field_data_corrupted_error if level_nested_field.blank? || level_nested_field.level != 3
    end
  end

  def nested_level_param_validation
    return if errors.present?

    df = dependent_fields.dup.sort_by { |a| a[:level] }
    df.each do |nested_level|
      name = :"#{tf[:label] || label}[level#{nested_level[:level]}]"
      # level 2 should not be empty
      # return errors[name] << :invalid_field if index.zero? && (nested_level.blank? || !nested_level.is_a?(Hash))

      # cases for create || update(when adding 3rd level in case of 2 level field)
      errors[name.to_s] << :dependent_field_level_error unless nested_level[:level] == 2 || nested_level[:level] == 3
      if create_action? || nested_level[:id].blank?
        new_nested_level_params_validation(nested_level.dup.symbolize_keys.keys, name)
      else # cases for update
        existing_nested_level_params_validation(nested_level.dup.symbolize_keys.keys, name)
      end
    end
  end

  def new_nested_level_params_validation(nested_level, name)
    uncommon_data = nested_level - DEPENDENT_FIELD_MANDATORY_PARAMS
    # id or ticket_field_id or any other garbage key present
    if uncommon_data.present?
      errors[name] << :invalid_attribute_for_key
      error_options[name] = { list: uncommon_data.join(', ') }
    end
    # for new it should match with hash field
    if (DEPENDENT_FIELD_MANDATORY_PARAMS & nested_level).length != DEPENDENT_FIELD_MANDATORY_PARAMS.length
      not_included_error(name, DEPENDENT_FIELD_MANDATORY_PARAMS.join(', '))
    end
    # for new, check their type
    DEPENDENT_FIELD_MANDATORY_PARAMS.each do |field|
      data_type_validation(nested_level, field, DEPENDENT_FIELD_PARAMS_WITH_TYPE[field], name)
    end
  end

  def existing_nested_level_params_validation(nested_level, name)
    # id and ticket_field_id should be present for update
    if (UPDATE_DEPENDENT_FIELD_PARAMS & nested_level).length != UPDATE_DEPENDENT_FIELD_PARAMS.length
      not_included_error(name, UPDATE_DEPENDENT_FIELD_PARAMS.join(', '))
    end
    # check their type
    ALLOWED_HASH_DEPENDENT_FIELDS.each do |field|
      data_type_validation(nested_level, field, ALLOWED_HASH_DEPENDENT_FIELDS[field], name)
    end
  end
end
