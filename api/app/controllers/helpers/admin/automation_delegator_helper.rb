module Admin::AutomationDelegatorHelper
  include Admin::AutomationConstants

  def validate_customer_field(contact, dom_type, form)
    case dom_type
    when :dropdown_blank
      validate_dropdown_dom(contact, :condition, form.to_sym)
    when :checkbox
      field_not_allowed("[:#{contact[:field_name]}][:value]") if contact.has_key? :value
    when :date
      validate_date_field(contact[:value])
    when :url
      invalid_value(contact[:field_name], contact[:value]) unless contact[:value].is_a?(String) || contact[:value].is_a?(Array)
    else
      validate_other_custom_field(contact[:field_name], contact[:value], CUSTOM_FIELD_TYPE_HASH[dom_type.to_sym])
    end
  end

  def validate_custom_ticket_field(ticket, field, dom_type, evaluate_on)
    case dom_type.to_sym
    when :nested_field
      validate_nested_field(field, ticket, evaluate_on)
    when :dropdown_blank
      validate_dropdown_dom(ticket, evaluate_on, :ticket)
    when :checkbox
      validate_checkbox(ticket, evaluate_on) if evaluate_on != :condition
    when :date
      validate_date_field(ticket[:value])
    end
  end

  def validate_checkbox(ticket, evaluate_on)
    not_included_error("#{evaluate_on}[:ticket][:#{ticket[:field_name]}][:value]",
                       CHECKBOX_VALUES) unless CHECKBOX_VALUES.include? ticket[:value]
  end

  def validate_dropdown_dom(field, evaluate_on, type)
    choices = fetch_dropdown_choices(field[:field_name], type, evaluate_on)
    actual = *field[:value]
    actual.each do |act|
      not_included_error("#{evaluate_on}[#{type}]#{field[:field_name]}[:value]", choices) unless choices.include? act
    end
  end

  def fetch_dropdown_choices(field_name, type, evaluate_on)
    case type
    when :ticket
      TicketsValidationHelper.custom_dropdown_field_choices["#{field_name}_#{current_account.id}"] + fetch_any_none(evaluate_on)
    when :contact
      contact_form_dropdown_choices(field_name) + fetch_any_none(evaluate_on)
    when :company
      company_form_dropdown_choices(field_name) + fetch_any_none(evaluate_on)
    end
  end

  def fetch_any_none(evaluate_on)
    case evaluate_on
    when :event
      ANY_NONE.values
    else
      [ANY_NONE[:NONE]]
    end
  end

  def validate_nested_field(field, actual, evaluate_on)
    if evaluate_on == :event
      validate_nested_field_event(field, field.picklist_values, actual)
    else
      validate_nested_values(field.picklist_values, actual)
    end
  end

  def translator_event_nested_field(actual, type)
    { field_name: actual[:field_name],
      value: actual[type.to_sym],
      nested_fields: actual["#{type}_nested_field".to_sym] }
  end

  def validate_nested_field_event(field, expected, actual)
    FROM_TO.each do |type|
      param = translator_event_nested_field(actual, type)
      validate_nested_values(expected, param)
    end
  end

  def validate_nested_values(level1_expected, actual)
    if actual[:value].is_a?(Array) || ANY_NONE.values.include?(actual[:value])
      if level1_expected.find_by_value(actual[:value]).blank? && !ANY_NONE.values.include?(actual[:value])
        not_included_error('actual[:value]', level1_expected.map(&:value))
      end
      field_not_allowed('ticket[:nested_field]') if actual[:nested_fields].present?
      return
    end
    if level1_expected.find_by_value(actual[:value]).blank? || ANY_NONE.values.include?(actual[:value])
      not_included_error("ticket[:#{actual[:field_name]}][:value]", level1_expected.map(&:value) + ANY_NONE.values)
      return
    end
    if actual[:nested_fields].present?
      level2_expected = level1_expected.find_by_value(actual[:value])
      validate_nested_level_type(level2_expected, actual, 'level2')
      return if errors.messages.present? || (ANY_NONE.values.include?(actual[:nested_fields][:level2][:value]) &&
          !actual[:nested_fields][:level3].present?)

      level3_expected = level2_expected.sub_picklist_values.find_by_value(actual[:nested_fields][:level2][:value])
      validate_nested_level_type(level3_expected, actual, 'level3')
    end
  end

  def validate_nested_level_type(expected, actual, level)
    return if actual[:nested_fields][level.to_sym].blank?

    if actual[:nested_fields][level.to_sym][:value].is_a?(Array)
      validate_array_type(expected, actual, level)
    else
      validate_each_level(expected, actual, level)
    end
  end

  def validate_each_level(expected, actual, level)
    if level == 'level2'
      if actual[:nested_fields][:level3].present? &&
          ANY_NONE.values.include?(actual[:nested_fields][level.to_sym][:value])
        field_not_allowed('level3')
        return
      end
      not_included_error(actual[:nested_fields][level.to_sym][:field_name], expected.sub_picklist_values.map(&:value)) if
          expected.sub_picklist_values.find_by_value(actual[:nested_fields][level.to_sym][:value]).blank? &&
              !ANY_NONE.values.include?(actual[:nested_fields][level.to_sym][:value])
    else
      not_included_error(actual[:nested_fields][:level3][:field_name], expected.sub_picklist_values.map(&:value)) if
          expected.sub_picklist_values.find_by_value(actual[:nested_fields][:level3][:value]).blank? &&
              !ANY_NONE.values.include?(actual[:nested_fields][level.to_sym][:value])
    end
  end

  def validate_array_type(expected, actual, level)
    if actual[:nested_fields][level.to_sym][:value].is_a?(Array)
      actual[:nested_fields][level.to_sym][:value].each do |val|
        not_included_error(level, expected.sub_picklist_values.map(&:value)) if
            expected.sub_picklist_values.find_by_value(val).blank?
      end
      field_not_allowed('level3') if actual[:nested_fields][:level3].present? && level == 'level2'
    else
      invalid_data_type(level, Array, actual[:nested_fields][level.to_sym][:value])
    end
  end

  def validate_default_ticket_field(name, value, data = nil)
    output = *value
    if TAGS.include? name
      tag_validation(name, output)
    elsif BUSINESS_HOURS_FIELDS.include?(name.to_sym)
      validate_business_calendar(name, data)
    elsif TIME_AND_STATUS_BASED_FILTER.include?(name.to_s)
      validate_time_status(name.to_sym, data)
    else
      any_value_error(name) if RESPONDER_ID == name && output.include?(ANY_NONE[:ANY]) && output.count > 1
      validate_field_values(name, output, default_fields[name.to_sym] + [*ANY_NONE[:NONE]])
    end
  end

  def validate_time_status(field_name, data)
    if data.present? && (field_name.to_s.eql? TIME_AND_STATUS_BASED_FILTER[0])
      if data['custom_status_id'].present?
        is_valid_status = Helpdesk::TicketStatus.status_objects_from_cache(current_account).select { |status| status.status_id == data['custom_status_id'] && !status.is_default }.present?
        invalid_value('custom_status_id', data['custom_status_id']) unless is_valid_status
        invalid_data_type('conditions[:condition_set_1][:ticket][:hours_since_waiting_on_custom_status][:value]', ['Number'],data['value'].class) unless data['value'].is_a?(Numeric)
      else
        missing_field_error('conditions[:condition_set_1][:ticket][:hours_since_waiting_on_custom_status]', ['custom_status_id'])
      end
    else
      missing_field_error('conditions[ticket]', ['hours_since_waiting_on_custom_status'])
    end
  end

  def validate_business_calendar(field_name, data)
    if data.present? && data.key?(:business_hours_id)
      unless business_calendars.include?(data[:business_hours_id])
        not_included_error("conditions[#{field_name}][:business_hours_id]", business_calendars)
      end
    else
      if business_calendars.count > 1 && current_account.multiple_business_hours_enabled?
        missing_field_error("conditions[#{field_name}]", :business_hours_id)
      end
    end
  end

  def validate_send_email(name, value)
    case name.to_sym
    when :send_email_to_group
      not_included_error(name, group_ids << 0) unless group_ids.include?(value.to_i) || value.to_i.zero?
    when :send_email_to_agent
      not_included_error(name, all_agents << 0) unless all_agents.include?(value.to_i) || value.to_i.zero?
    end
  end

  def validate_notify_agents(field_name,agent_ids)
    invalid_agent_ids = agent_ids - all_agents
    if invalid_agent_ids.length > 0
      errors[field_name.to_sym] << :invalid_value_in_field
      (error_options[field_name.to_sym] ||= {}).merge!(field_name: :notify_agents, value: invalid_agent_ids.join(', '))
    end
  end

  def validate_field_values(name, value, source_list)
    not_included_error(name, source_list) if (value & source_list).size != value.size
  end
  
  def validate_case_sensitive(field, dom_type, type = nil)
    field_not_allowed("#{type}case_sensitive") unless CASE_SENSITIVE_FIELDS.include?(dom_type.to_sym)
    not_included_error("#{type}#{field[:field_name]}", BOOLEAN) unless BOOLEAN.include?(field[:case_sensitive])
  end

  def tag_validation(name, values)
    if name.to_sym == :add_tag
      values.first.split(',').each do |value|
        invalid_data_type(name, String, value.class) unless value.is_a?(String)
      end
    else
      values.each do |value|
        next if ANY_NONE.values.include?(value)
        invalid_value(name, value) if current_account.tags.find_by_name(value).blank?
      end
    end
  end

  def default_fields
    @default_fields ||= {
        status: ticket_statuses,
        product_id: product_ids,
        group_id: group_ids,
        add_watcher: all_agents,
        responder_id: all_agents + [ANY_NONE[:ANY]],
        internal_agent_id: all_agents,
        internal_group_id: group_ids,
        ticket_type: ticket_types,
        source: ticket_sources,
        priority: ApiTicketConstants::PRIORITIES,
        created_at: VAConfig::CREATED_DURING_NAMES_BY_KEY.values,
        note_type: EVENT_NOTE_TYPE,
        ticket_action: TICKET_ACTION,
        time_sheet_action: TIME_SHEET_ACTION,
        customer_feedback: CUSTOMER_FEEDBACK_RATINGS,
        language: LANGUAGE_CODES,
        time_zone: ContactConstants::TIMEZONES,
        freddy_suggestion: FREDDY_ACCEPTED_VALUES
    }
    @default_fields.merge!(tam_fields) if current_account.tam_default_fields_enabled?
    @default_fields
  end

  def tam_fields
    @tam_fields ||= {
        account_tier: valid_account_tier_choices,
        industry: valid_industry_choices,
        health_score: valid_health_score_choices
    }
  end

  def validate_date_field(value)
    begin
      value.to_date
    rescue Exception
      errors[:invalid_date] << :invalid_date
      (error_options[:invalid_date] ||= {}).merge!(accepted: 'YYYY-MM-DD')
    end
  end

  def validate_other_custom_field(name, *value, type)
    name = name.chomp("_#{current_account.id}") if name.ends_with? "_#{current_account.id}"
    value.flatten.each do |val|
      invalid_data_type(name, type, val) unless val.is_a? type
    end
  end

  def current_account
    @current_account ||= Account.current
  end

  def ticket_field_names
    @ticket_field_names ||= custom_ticket_fields.map &:field_name
  end

  def company_name_validation(value)
    values = *value
    values.each do |val|
      invalid_value('company[:name]', value) if current_account.companies.find_by_name(value).blank?
    end
  end

  def company_domain_validation(value)
    values = *value
    values.each do |val|
      invalid_value('company[:domains]', val) unless val.is_a?(String)
    end
    # TODO: For now we are doing string validation only
    # values.each do |val|
    #   invalid_value('company[:domains]', val) if current_account.company_domains.find_by_domain(val).blank?
    # end
  end

  def invalid_data_type(name, expected, actual)
    errors[name.to_sym] << :invalid_data_type
    (error_options[name.to_sym] ||= {}).merge!(expected_type: expected, actual_type: actual)
  end

  def not_included_error(field, list)
    field = field.chomp("_#{current_account.id}") if field.ends_with? "_#{current_account.id}"
    errors[field.to_sym] << :not_included
    (error_options[field.to_sym] ||= {}).merge!(list: list.join(', '))
  end

  def field_not_allowed(field)
    field = field.chomp("_#{current_account.id}") if field.ends_with? "_#{current_account.id}"
    errors[field.to_sym] << :field_not_allowed
    (error_options[field.to_sym] ||= {}).merge!(field: field)
  end

  def field_not_found_error(field_name)
    field_name = field_name.chomp("_#{current_account.id}") if field_name.ends_with? "_#{current_account.id}"
    errors[field_name.to_sym] << :invalid_field_name
    (error_options[field_name.to_sym] ||= {}).merge!(field_name: field_name)
  end

  def invalid_value(field_name, value, message = :invalid_value_in_field )
    field_name = field_name.chomp("_#{current_account.id}") if field_name.ends_with? "_#{current_account.id}"
    errors[field_name.to_sym] << message
    (error_options[field_name.to_sym] ||= {}).merge!(field_name: field_name, value: value)
  end

  def absent_in_db_error(field_name, value, list)
    values = *value
    unless (values & list) == values
      errors[field_name.to_sym] << :absent_in_db
      (error_options[field_name.to_sym] ||= {}).merge!(resource: field_name, attribute: values.join(', '))
    end
  end

  def level_field_not_allowed(field_name, level)
    field_name = field_name.chomp("_#{current_account.id}") if field_name.ends_with? "_#{current_account.id}"
    errors[:"#{level}:[#{field_name}]"] << :level_field_not_allowed
    (error_options[:"#{level}:[#{field_name}]"] ||= {}).merge!(field_name: field_name, level: level)
  end

  def level_field_missing(field)
    errors[field.to_sym] << :level_missing_field
    (error_options[field.to_sym] ||= {}).merge!(field: field)
  end

  def field_not_found(field_name)
    errors[field_name.to_sym] << :field_not_found
    (error_options[field_name.to_sym] ||= {}).merge!(field_name: field_name)
  end

  def missing_field_error(name, value)
    errors[name.to_sym] << :expecting_value_for_event_field
    (error_options[name.to_sym] ||= {}).merge!(name: name, value: value)
  end

  def duplicate_rule_name_error(name)
    errors[:name] << :duplicate_name_in_automations
    (error_options[:name] ||= {}).merge!(name: name)
  end

  def any_value_error(field_name)
    errors[field_name.to_sym] << :any_value_error
    (error_options[field_name.to_sym] ||= {})
  end

  def custom_ticket_fields
    @custom_ticket_fields ||= current_account.ticket_fields_from_cache
  end

  def company_form
    @company_form ||= current_account.company_form
  end

  def company_form_fields
    @company_form_fields ||= company_form.company_fields_from_cache
  end

  def contact_form
    @contact_form ||= current_account.contact_form
  end

  def contact_form_fields
    @contact_form_fields ||= contact_form.contact_fields_from_cache
  end

  def all_agents
    @all_agents ||= current_account.technicians.map(&:id)
  end

  def contact_form_dropdown_choices(field_name)
    contact_form.custom_contact_fields.select { |c| c.name == field_name }.map { |x| x.choices.map { |t| t[:value] } }.first
  end

  def company_form_dropdown_choices(field_name)
    company_form.custom_company_fields.select { |c| c.name == field_name }.map { |x| x.choices.map { |t| t[:value] } }.first
  end

  private

  def internal_group_ids
    @internal_group_ids  ||= current_account.account_status_groups_from_cache.collect(&:group_id).uniq
  end

  def internal_agent_ids
    @internal_agent_ids  ||= current_account.agent_groups.where(:group_id => internal_group_ids).pluck(:user_id).uniq
  end

  def valid_health_score_choices
    @valid_health_score_choices ||= company_form.default_health_score_choices
  end

  def valid_account_tier_choices
    @valid_account_tier_choices ||= company_form.default_account_tier_choices
  end

  def valid_industry_choices
    @valid_industry_choices ||= company_form.default_industry_choices
  end

  def ticket_statuses
    @ticket_statuses ||= current_account.ticket_statuses.collect(&:status_id)
  end

  def ticket_sources
    @ticket_sources ||= current_account.ticket_source_from_cache.map(&:account_choice_id)
  end

  def product_ids
    @product_ids ||= current_account.products_from_cache.collect(&:id)
  end

  def group_ids
    @group_ids ||= current_account.groups_from_cache.collect(&:id)
  end

  def ticket_types
    @ticket_types ||= current_account.ticket_types_from_cache.collect { |t| t.value }
  end

  def business_calendars
    @busines_hours_ids ||= current_account.business_calendar.pluck(:id)
  end

  AUTOMATION_RULE_TYPES.each do |item|
    define_method "#{item.to_s}_rule?" do
      rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
      rule_name == item
    end
  end
end
