module Admin::CustomFieldHelper
  include Admin::ConditionConstants

  def validate_nested_field(expected, actual, validator_type, nested_name)
    # parent_data = actual.select { |key| VALID_DEFAULT_REQUEST_PARAMS_HASH.include?(key) }
    if NESTED_EVENT_LABEL.include?(nested_name)
      parent_value = nested_name == :from_nested_field ? actual[:from] : actual[:to]
      safe_send(:"validate_#{validator_type}_from_to", expected, actual)
    else
      parent_value = actual[:value]
      safe_send(:"validate_#{validator_type}_value", expected, actual)
    end
    validate_sub_level(expected, actual, actual[:operator], parent_value, validator_type, nested_name)
  end

  def validate_sub_level(expected, actual, parent_operator, parent_value, validator_type, nested_name)
    NESTED_LEVEL_COUNT.times do |level_num|
      level_name = :"level#{level_num + NESTED_LEVEL_COUNT}"
      level_data = actual[nested_name].try(:[], level_name)
      break if invalid_nested_level?(expected[:name], parent_operator, nested_name, parent_value, level_name, level_data)
      nested_expected = expected.dup
      nested_expected[:name] = expected[level_name]
      safe_send :"validate_#{validator_type}_value", nested_expected, level_data.dup
      parent_operator, parent_value = level_data[:operator], level_data[:value]
    end
  end

  def invalid_nested_level?(name, operator, nested_name, value, level_name, level_data)
    must_have_nested = expect_nested_level?(operator, value)
    error_field = true
    if (level_name == :level3 || level_name == :level2) && level_data.blank?
      error_field = true
    elsif must_have_nested && level_data.blank?
      missing_field_error("#{name}[#{nested_name}]", level_name)
    elsif !must_have_nested && level_data.present?
      unexpected_parameter("#{name}[#{nested_name}][#{level_name}]", :extra_level_field)
    else
      error_field = false
    end
    error_field || !must_have_nested
  end

  def expect_nested_level?(operator, value)
    operator = (operator.to_sym rescue operator)
    if operator.present?
      no_nested = ARRAY_VALUE_EXPECTING_OPERATOR.include?(operator)
      no_nested ||= (SINGLE_VALUE_EXPECTING_OPERATOR.include?(operator) && any_none_value?(value, true))
      no_nested ||= operator == :is_not
    else
      no_nested = any_none_value?(value, true)
    end
    !no_nested # not expecting nested level
  end

  def custom_condition_ticket_field
    condition_field = custom_ticket_fields.select do |tf|
      CUSTOM_FIELD_CONDITION_HASH[tf.field_type.to_sym].present? &&
        !(params[:rule_type].to_i == 3 &&
            SUPERVISOR_FEATURE_CUSTOM_FIELDS.include?(tf.field_type.to_sym) && !current_account.supervisor_text_field_enabled?)
    end
    custom_fields = []
    field_hash = []
    condition_field.each do |ef|
      cf_name = TicketDecorator.display_name(ef.name).to_sym
      next if ef.level.present? # ignore nested sublevel
      custom_data = { name: cf_name }
      custom_data.merge!(nested_field_sublevel_names(ef.id)) if ef.field_type == "nested_field"
      field_hash << CUSTOM_FIELD_CONDITION_HASH[ef.field_type.to_sym].merge(custom_data)
      custom_fields << cf_name
    end
    [custom_fields, field_hash]
  end

  def custom_condition_contact
    condition_field = contact_form_fields.select{ |cf| CUSTOM_CONDITION_CONTACT_HASH[cf.field_type.to_sym].present? }
    custom_fields = []
    field_hash = []
    condition_field.each do |cf|
      cf_name = cf.name.to_sym
      field_hash << CUSTOM_CONDITION_CONTACT_HASH[cf.field_type.to_sym].merge({ name: cf_name })
      custom_fields << cf_name
    end
    [custom_fields, field_hash]
  end

  def custom_condition_company
    condition_field = company_form_fields.select{ |cf| CUSTOM_CONDITION_COMPANY_HASH[cf.field_type.to_sym].present? }
    custom_fields = []
    field_hash = []
    condition_field.each do |cf|
      cf_name = cf.name.to_sym
      field_hash << CUSTOM_CONDITION_COMPANY_HASH[cf.field_type.to_sym].merge({ name: cf_name })
      custom_fields << cf_name
    end
    [custom_fields, field_hash]
  end

  def custom_ticket_fields
    @custom_ticket_fields ||= ticket_fields.select{ |tf| !tf.default }
  end

  def nested_field_sublevel_names(parent_id)
    nested_field_sub_level = custom_ticket_fields.select{ |tf| tf.parent_id == parent_id }
    nested_field_sub_level.sort{|tf1, tf2| tf1.level <=> tf2.level }
    level2name = nested_field_sub_level.try(:[], 0).try(:[], 'name')
    level2name = level2name.split("_#{current_account.id}")[0].to_sym if level2name.present?
    level3name = nested_field_sub_level.try(:[], 1).try(:[], 'name')
    level3name = level3name.split("_#{current_account.id}")[0].to_sym if level3name.present?
    { level2: level2name, level3: level3name }
  end

  def ticket_fields
    @ticket_fields ||= current_account.ticket_fields_from_cache
  end

  def company_form_fields
    @company_form_fields ||= company_form.company_fields_from_cache.select{ |cf| cf.column_name != 'default' }
  end

  def company_form
    @company_form ||= current_account.company_form
  end

  def contact_form_fields
    @contact_form_fields ||= contact_form.contact_fields_from_cache.select{ |cf| cf.column_name != 'default' }
  end

  def contact_form
    @contact_form ||= current_account.contact_form
  end

  def current_account
    @current_account ||= Account.current
  end
end