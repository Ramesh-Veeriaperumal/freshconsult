class Admin::AutomationDecorator < ApiDecorator
  include Admin::AutomationConstants
  include Admin::Automation::AutomationSummary
  delegate :id, :name, :position, :active, :created_at, :outdated, :last_updated_by, :affected_tickets_count, to: :record
  DEFAULT_EVALUATE_ON = 'ticket'.freeze

  def initialize(record, _options)
    super(record)
  end

  def to_hash(add_html_tag = true, list_page = false)
    response = {
      name: name,
      position: position,
      active: active,
      outdated: outdated,
      last_updated_by: last_updated_by,
      id: id,
      summary: generate_summary(record, add_html_tag),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }.merge!(automation_hash)
    if current_account.automation_rule_execution_count_enabled?
      response.merge!(affected_tickets_count: affected_tickets_count)
    end
    response.merge!(meta: meta_hash) unless list_page
    response
  end

  private

    def meta_hash
      {
        total_active_count: current_account.account_va_rules.where(rule_type: record.rule_type.to_i, active: true).count,
        total_count: current_account.account_va_rules.where(rule_type: record.rule_type.to_i).count
      }
    end

    def automation_hash
      AUTOMATION_FIELDS[VAConfig::RULES_BY_ID[record.rule_type]].inject({}) do |hash, key|
        hash.merge!(key.to_sym => safe_send("#{key}_hash"))
      end
    end

    def performer_hash
      return {} if record.rule_performer.nil?
      PERFORMER_FIELDS.inject({}) do |hash, key|
        val = record.rule_performer.instance_variable_get("@#{key}")
        val = val.to_i if key == :type
        hash.merge!(construct_data(key.to_sym, val,
                                   record.rule_performer.instance_variable_defined?("@#{key}")))
      end
    end

    def events_hash
      return [] if record.rule_events.nil?
      record.rule_events.map do |event|
        event_hash = EVENT_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key.to_sym, event.rule[key], event.rule.key?(key), EVENT_NESTED_FIELDS, nil, nil, true))
        end
        event_hash = event_hash.symbolize_keys
        reconstruct_nested_data(event_hash) if (event_hash.keys & NESTED_FIELD_CONSTANTS.values).present?
        event_hash
      end
    end

    def reconstruct_nested_data(data_hash)
      %i[from to value].each do |nested_key|
        parent = ANY_NONE_VALUES.include?(data_hash[nested_key])
        data_hash.delete NESTED_FIELD_CONSTANTS[nested_key] if parent

        nested_field = data_hash[NESTED_FIELD_CONSTANTS[nested_key]]
        next if nested_field.blank? || !nested_field.is_a?(Hash)
        nested_field.symbolize_keys!
        NESTED_LEVEL_COUNT.times do |_level_num|
          nested_field.delete :"level#{_level_num + NESTED_LEVEL_COUNT}" if parent
          nested_data = nested_field[:"level#{_level_num + NESTED_LEVEL_COUNT}"]
          next if nested_data.blank? || !nested_data.is_a?(Hash)
          nested_data.symbolize_keys!
          current = ANY_NONE_VALUES.include?(nested_data[:value])
          parent = current
        end
      end
    end

    def conditions_hash
      return {} if record.rule_conditions.nil?
      condition_data_hash(record.rule_conditions,
                          record.rule_operator)
    end

    def construct_action_nested_fields(action)
      action_data = { field_name: TicketDecorator.display_name(action[:category_name].to_s) }
      (ACTION_FIELDS - %i[name]).each do |key|
        action_data.merge!(construct_data(key.to_sym, action[key], action.key?(key), CONDITON_SET_NESTED_FIELDS))
      end
      action_data
    end

    def actions_hash
      return {} if record.action_data.nil?
      record.action_data.map do |action|
        if action.key?(:nested_rules)
          construct_action_nested_fields(action)
        elsif action[:name].to_sym == :trigger_webhook
          construct_webhook(action)
        else
          ACTION_FIELDS.inject({}) do |hash, key|
            action[:value] = action[:value].split(',').flatten if action[:name].to_sym == :add_tag
            hash.merge!(construct_data(key.to_sym, action[key], action.key?(key)))
          end
        end
      end
    end

    def condition_data_hash(condition_data, operator)
      nested_condition = (condition_data.first &&
          (condition_data.first.key?(:all) || condition_data.first.key?(:any)))
      if nested_condition
        condition_data.each_with_index.inject({}) do |hash, (condition_set, index)|
          hash[:operator] = READABLE_OPERATOR[operator.to_s] if index == 1
          hash.merge!("condition_set_#{index + 1}".to_sym =>
              condition_set_hash(condition_set.values.first, condition_set.keys.first))
        end
      else
        { 'condition_set_1'.to_sym => condition_set_hash(condition_data, operator) }
      end
    end

    def condition_set_hash(condition_set, match_type)
      condition_hash = { match_type: match_type }
      condition_set.each do |condition|
        condition.deep_symbolize_keys
        evaluate_on_type = condition[:evaluate_on] || DEFAULT_EVALUATE_ON
        evaluate_on = EVALUATE_ON_MAPPING_INVERT[evaluate_on_type.to_sym] || evaluate_on_type.to_sym
        condition_hash[evaluate_on] ||= []
        condition_set_data = CONDITION_SET_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key.to_sym, condition[key], condition.key?(key),
                                     CONDITON_SET_NESTED_FIELDS, hash[:field_name], evaluate_on))
        end
        support_for_old_operators(condition_set_data)
        condition_hash[evaluate_on] << condition_set_data
      end
      condition_hash
    end

    def construct_nested_data(nested_values)
      nested_values && nested_values.each_with_index.inject({}) do |nested_hash, (nested_value, index)|
        nested_hash.merge!("level#{index + 2}".to_sym => NESTED_DATA_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key.to_sym, nested_value[key], nested_value.key?(key), nil, nil, nil, true))
        end)
      end
    end

    def construct_webhook(action)
      action = action.deep_symbolize_keys
      action_hash = {
          content_type: Va::Constants::WEBHOOK_CONTENT_TYPES[action[:content_type]].to_s,
          content_layout: action[:content_layout].to_s,
          request_type: Va::Constants::WEBHOOK_REQUEST_TYPES[action[:request_type]].to_s,
          content: action[:params],
          url: action[:url],
          field_name: action[:name]
      }
      action_hash.select! { |_, value| value.present? }
      if action.key?(:need_authentication)
        action_hash.delete :need_authentication
        action_hash[:auth_header] = {}
        action_hash[:auth_header][:username] = action[:username] if action[:username].present?
        action_hash[:auth_header][:password] = MASKED_FIELDS[:password] if action[:password].present?
        action_hash[:auth_header][:api_key] = action[:api_key] if action[:api_key].present?
      end
      action_hash
    end

    def construct_data(key, value, has_key, nested_field_names = nil, field_name=nil, evaluate_on = nil, is_event = false)
      key = FIELD_NAME_CHANGE_MAPPING[key] if FIELD_NAME_CHANGE.include?(key)
      value = construct_nested_data(value) if
              nested_field_names.present? && nested_field_names.include?(key)
      value = MASKED_FIELDS[key] if MASKED_FIELDS.key? key
      if key == :field_name
        value = FIELD_VALUE_CHANGE_MAPPING[value.to_sym] if FIELD_VALUE_CHANGE_MAPPING.include?(value.to_sym)
        value = TicketDecorator.display_name(value.to_s) if value.to_s.ends_with?("_#{current_account.id}")
        value = SUPERVISOR_FIELD_VIEW_MAPPING[value.to_sym].to_s if record.supervisor_rule? && SUPERVISOR_FIELD_VIEW_MAPPING.key?(value.to_sym)
        value = CustomFieldDecorator.display_name(value) if (evaluate_on == :contact || evaluate_on == :company) && 
                                                            !COMPANY_FIELDS.include?(value.to_sym) && 
                                                            !CONDITION_CONTACT_FIELDS.include?(value.to_sym)
        if is_event && value.present? && TRANSFORMABLE_EVENT_FIELDS.include?(key.to_sym) && !DEFAULT_EVENT_TICKET_FIELDS.include?(value.to_sym)
          field = current_account.ticket_fields_from_cache.find { |tf| tf.column_name == value }
          value = TicketDecorator.display_name(field.name) if field.present?
        end
      end
      if key == :value && field_name == :tag_names
        value = current_account.tags.where("id in (?)", value).pluck(:name)
      end
      has_key ? { key => value } : {}
    end


    def support_for_old_operators(data)
      data.symbolize_keys!
      if data[:operator].is_a?(String) && OLD_OPERATOR_MAPPING.key?(data[:operator].to_sym)
        data[:value] = *data[:value]
        data[:operator] = OLD_OPERATOR_MAPPING[data[:operator].to_sym]
      end
    end
end
