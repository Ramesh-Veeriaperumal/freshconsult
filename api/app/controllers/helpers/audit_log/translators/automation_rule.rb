module AuditLog::Translators::AutomationRule
  def readable_rule_changes(model_changes)
    model_changes.keys.each do |attribute|
      case attribute
      when :filter_data
        if dispatcher_rule? || supervisor_rule?
          translate_filter_action(model_changes[attribute], :conditions)
        elsif observer_rule?
          translate_observer_events(model_changes[attribute])
        end
      when :action_data
        translate_filter_action(model_changes[attribute], :actions)
      when :active
        model_changes[attribute] = [
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][0]],
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][1]]
        ]
      end
    end
    model_changes
  end

  def translate_observer_events(model_changes)
    %i[events performer conditions].each do |key|
      case key
      when :events
        translate_filter_action([model_changes[0][key], model_changes[1][key]], :events)
      when :performer
        model_changes.each do |changes|
          changes[key][:field] = Va::Performer::TYPE_CHECK[changes[key][:type]][:english_key]
          changes[key][:type] = 'default'
          next unless changes[key].key?(:members)
          changes[key][:value] = agent_list.to_a.select do |arr|
            changes[key][:members].include? arr[0]
          end.map {|ar| ar[1]}
          changes.delete :members
        end
      when :conditions
        translate_filter_action([model_changes[0][key], model_changes[1][key]], :conditions)
      end
    end
  end

  def translate_filter_action(model_changes, type)
    translated_items = Va::Constants.send("readable_#{type}")
    model_changes.each do |actions|
      actions.each do |action|
        readable = assign_readable(action, translated_items)
        translate_send_email_to(action, readable)
        translate_webhook(action, readable)
        translate_name(action, readable, type)
        translate_operator(action)
        translate_values(action, readable)
        translate_dependent_fields(action, readable)
        if action.key?(:from) && action.key?(:to)
          action[:value] = {
            :from => action.delete(:from),
            :to => action.delete(:to)
          }
        end
      end
    end
  end

  def assign_readable(action, translated_items)
    name_key = action.key?(:evaluate_on) && action[:evaluate_on] != 'ticket' ?
                    "#{action[:evaluate_on]}_#{action[:name]}" :
                    action[:name]
    name_key = 'created_at_supervisor' if supervisor_rule? && name_key == 'created_at'
    translated_items[name_key]
  end

  def customize_field_name(field_name, type)
    customize_name = I18n.t("admin.audit_log.automation_rule.custom_field_name", field_name: field_name)
    type == :actions ? customize_name : field_name
  end

  def translate_name(action, readable, type)
    return action[:name] = readable[0] if readable.present?
    name = action[:category_name] || action[:name]
    field_name, field_type = custom_field_name(name, action[:evaluate_on])
    action[:name] = customize_field_name(field_name, type) if field_name.present?
    if field_type.present? && field_type.include?('checkbox')
      action[:value] = Va::Constants.checkbox_options[action[:value]]
      checkbox_values = ["selected", "not_selected"]
      unless action[:value].present?
        action[:operator] = Va::Constants.checkbox_options["#{checkbox_values.find_index(action[:operator])}"]
      end
    end
  end

  def translate_operator(action)
    action[:operator] = action[:operator].tr('_', ' ') if action.key?(:operator)
  end

  def translate_values(action, readable)
    %i[value from to].each do |key|
      next unless action.key?(key)
      if action[key] == '--'
        action[key] = I18n.t('any')
        next
      end
      if action[key] == ''
        action[key] = I18n.t('none')
        next
      end
      if action[key].is_a?(Array) && action[key].include?('')
        action[key].delete('')
        action[key] << I18n.t('none')
      end
      next unless readable.present? && readable.length > 1
      if readable[1].is_a?(Hash)
        action[key] = if action[key].is_a?(String)
                        readable[1][action[key]]
                      else
                        action[key].map {|val| readable[1][val]}.join(', ')
                      end
        next
      end
      actionable = Account.current.safe_send(readable[1])
                          .safe_send("find_all_by_#{readable[2]}", action[key])
      readable_value = if actionable.present?
                         val = actionable.map do |act|
                           act.respond_to?('name') ? act.name : act.value
                         end
                         val << I18n.t('none') if (action[key].respond_to? :include?) && action[key].include?(I18n.t('none'))
                         val.join(', ')
                       else
                         ''
                       end
      action[key] = readable_value
    end
  end

  def filter_value_by_key(data, key)
    result = []
    if data.is_a? Array
      result = data
    else
      result << { name: data[:name], value: data[key] }
    end
    result
  end

  def translate_dependent_fields(action, readable)
    if action.key?(:nested_rules) || action.key?(:nested_rule)
      rules = {from: :from_nested_rules, to: :to_nested_rules, value: :nested_rules}
      field_changes = []
      rules.each_pair do |key, type|
        next unless action[type].present?
        action[type].each do |rule|
          translate_name(rule, nil, nil)
          translate_values(rule, readable)
        end
        field_changes << filter_value_by_key(action, key)
        field_changes[field_changes.length - 1] = field_changes.last + filter_value_by_key(action[type], key)
      end
      field_name = action[:name]
      format_action(action)
      action[:field] = field_name
      action[:type] = 'nested'
      action[:value] = field_changes.length > 1 ? { from: field_changes[0], to: field_changes[1] } : field_changes[0]
    end
  end

  def translate_send_email_to(action, _readable)
    if action[:name] && action[:name].start_with?('send_email_to')
      action[:type] = :send_email_to
      if action[:name] == 'send_email_to_agent'
        agent_name = agent_list[action[:email_to]]
        action[:email_to] = agent_name if agent_name.present?
      elsif action[:name] == 'send_email_to_group'
        group_name = group_list[action[:email_to]]
        action[:email_to] = group_name if group_name.present?
      end
      format_action(action)
    end
  end

  def translate_webhook(action, _readable)
    if action[:name] == 'trigger_webhook'
      action[:type] = :webhook
      action[:content_type] = Va::Constants::WEBHOOK_CONTENT_TYPES[action[:content_type]]
      action[:request_type] = Va::Constants::WEBHOOK_REQUEST_TYPES[action[:request_type]]
      action[:content_layout] = Va::Constants.webhook_content_layouts[action[:content_layout]]
      format_action(action)
    end
  end

  def agent_list
    @agent_list ||= begin
      list = Account.current.agents_from_cache.map {|agent| [agent.user_id.to_s, agent.name]}
      list.push(['0', I18n.t('admin.observer_rules.assigned_agent')],
                ['-2', I18n.t('admin.observer_rules.event_performer')])
      list.to_h
    end
  end

  def group_list
    @group_list ||= begin
      list = Account.current.groups_from_cache.map {|group| [group.id.to_s, group.name]}
      list.push(['0', I18n.t('admin.observer_rules.assigned_group')])
      list.to_h
    end
  end

  def custom_field_name(name, evaluate_on)
    evaluate_on ||= 'ticket'
    case evaluate_on
    when 'requester'
      @custom_requester_fields ||= Account.current.contact_form.custom_fields
    when 'company'
      @custom_company_fields ||= Account.current.company_form.custom_fields
    when 'ticket'
      @custom_ticket_fields ||= Account.current.ticket_fields_from_cache
    end
    fields = instance_variable_get("@custom_#{evaluate_on}_fields")
    if fields.present?
      if evaluate_on == 'ticket'
        field = fields.find { |field| field.name == name ||
        (field.flexifield_def_entry.present? &&
          field.flexifield_def_entry.flexifield_name == name) }
      else 
        field = fields.find { |field| field.name == name }
      end
      [field.label, field.field_type.to_s] if field.present?
    end
  end

  def format_action(action)
    keys = [:type, :operator]
    values = action.reject {|field| keys.include? field.to_sym}
    action.select! {|field| keys.include? field.to_sym}
    action.merge!(value: values)
  end

  def set_rule_type(rule_type)
    @rule_type = rule_type
  end

  def dispatcher_rule?
    @rule_type == VAConfig::BUSINESS_RULE
  end

  def observer_rule?
    @rule_type == VAConfig::OBSERVER_RULE
  end

  def supervisor_rule?
    @rule_type == VAConfig::SUPERVISOR_RULE
  end
end
