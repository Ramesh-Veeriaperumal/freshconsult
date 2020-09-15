module Admin::TicketFieldsErrorHelper
  def missing_feature_error(name, value = nil, message = :require_feature)
    errors[name] << message
    error_message = {}
    error_message[name] = { feature: name, code: :access_denied }
    error_message[name][:attribute] = value if value
    error_options.merge!(error_message)
  end

  def missing_param_error(name, params, message = :missing_ticket_field_params)
    errors[name] << message
    error_message = {}
    error_message[name] = { params: params }
    error_options.merge!(error_message)
  end

  def default_field_error(name, field, message = :default_field_modified)
    errors[name] << message
    error_message = {}
    error_message[name] = { field: field }
    error_options.merge!(error_message)
  end

  def invalid_section_mapping_error(name, section_id = nil, message = :invalid_section_mapping)
    errors[name] << message
    if section_id
      error_message = {}
      error_message[name] = { section_id: section_id }
      error_options.merge!(error_message)
    end
  end

  def invalid_data_type(name, expected, actual, message = :invalid_data_type)
    errors[name] << message
    error_message = {}
    error_message[name] = { expected_type: expected, actual_type: actual }
    error_options.merge!(error_message)
  end

  def unexpected_value_for_attribute(name, value, message = :unexpected_parameter_error)
    errors[name] << message
    error_message = {}
    error_message[name] = { name: name, value: value }
    error_options.merge!(error_message)
  end

  def blank_value_for_attribute(name, value, message = :cannot_be_blank)
    errors[name] << message
    error_message = {}
    error_message[name] = { name: value }
    error_options.merge!(error_message)
  end

  def limit_exceeded_error(type, limit, message = :ticket_field_exceeded_limit)
    errors[type] << message
    error_message = {}
    error_message[type] = { field_type: type, limit: limit, code: :exceeded_limit }
    error_options.merge!(error_message)
  end

  def duplicate_label_error(name, label, message = :duplicate_label_ticket_field)
    errors[name] << message
    error_message = {}
    error_message[name] = { label: label }
    error_options.merge!(error_message)
  end

  def merge_to_parent_errors(validation)
    validation.errors.to_h.each_pair do |key, value|
      errors[key] << value
    end
    error_options.merge! validation.error_options
  end

  def source_icon_id_error(name, to, from = 1, message = :invalid_value_for_icon_id)
    errors[name] << message
    range = to.nil? ? from : "#{from} to #{to}"
    error_message = {}
    error_message[name] = { range: range }
    error_options.merge!(error_message)
  end

  def choice_position_error(tf, choice_level, to, from = 1)
    name = "#{tf.label}[#{choice_level}]".intern
    errors[name] << :invalid_position_for_choices
    error_message = {}
    range = to.nil? ? from : "#{from} to #{to}"
    error_message[name] = { range: range }
    error_options.merge!(error_message)
  end

  def ticket_field_position_error(tf, to, from = 1)
    name = "#{tf.label}[:position]".intern
    errors[name] << :invalid_position_for_choices
    error_message = {}
    range = to.nil? ? from : "#{from} to #{to}"
    error_message[name] = { range: range }
    error_options.merge!(error_message)
  end

  def duplication_choice_error(tf, choices, choice_level, field = 'value')
    errors[:"#{tf.label}[#{choice_level}]"] << :duplicate_choice_for_ticket_field
    error_options[:"#{tf.label}[#{choice_level}]"] = { field: field, value: choices.join(', ') }
  end

  def not_included_error(name, list, message: :not_included)
    errors[name] << message
    error_message = {}
    error_message[name] = { list: list }
    error_options.merge!(error_message)
  end

  def absent_in_db_error(name, field, column, message: :absent_in_db)
    errors[name] << message
    error_message = {}
    error_message[name] = { resource: field, attribute: column }
    error_options.merge!(error_message)
  end

  def custom_field_limit_exceeded(type)
    @errors = [BadRequestError.new(type, :field_limit_exceeded)]
    render '/bad_request_error', status: 400
  end

  def custom_empty_param_error
    @errors = [BadRequestError.new(:body, :"can't be blank")]
    render '/bad_request_error', status: 400
  end

  def level_choices_delete_error(name, level, message: 'level_choices_deletion_error')
    errors[name] << message
    error_message = {}
    error_message[name] = { level: level }
    error_options.merge!(error_message)
  end

  def choice_id_taken_error(name, choice_id, message: :choice_id_taken)
    errors[name] << message
    error_message = {}
    error_message[name] = { id: choice_id }
    error_options.merge!(error_message)
  end

  def default_field_archive_or_deletion_error(name, operation, message: :delete_default_field_error)
    errors[name] << message
    error_message = {}
    error_message[name] = { name: name, operation: operation }
    error_options.merge!(error_message)
  end

  def section_inside_ticket_field_error(name, operation, message: :section_inside_ticket_field_error)
    errors[name] << message
    error_message = {}
    error_message[name] = { name: name, operation: operation }
    error_options.merge!(error_message)
  end

  def ticket_field_job_progress_error
    errors[:ticket_field_update] << :field_update_job_running_error
  end

  def fsm_enabled_error(name, operation, message: :fsm_enabled)
    errors[name] << message
    error_message = {}
    error_message[name] = { operation: operation }
    error_options.merge!(error_message)
  end
end
