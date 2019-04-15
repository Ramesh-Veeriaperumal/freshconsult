# This Admin::AutomationHelper is helper for automations_controller
module Admin::AutomationHelper
  include Admin::AutomationConstants

  private

    def check_automation_params
      params[cname].permit(*PERMITTED_PARAMS)
      %i[performer events conditions actions].each do |key|
        safe_send(:"check_#{key}_params") if params[cname].present? && params[cname][key].present?
      end
    end

    def check_conditions_params
      params[cname][:conditions].permit(*CONDITIONS_REQUEST_PRAMS)
      check_condition_set_params
    end

    def check_events_params
      if params[cname][:events].is_a? Array
        params[cname][:events].map { |event| event.permit(*EVENT_REQUEST_PRAMS) }
      end
    end

    def check_actions_params
      if params[cname][:actions].is_a? Array
        params[cname][:actions].map { |action| action.permit(*ACTION_REQUEST_PRAMS) }
      end
    end

    def check_performer_params
      params[cname][:performer].permit(*PERFORMER_REQUEST_PRAMS)
    end

    def check_condition_set_params
      %i[condition_set_1 condition_set_2].each do |key|
        if params[cname][:conditions][key].present?
          params[cname][:conditions][key].permit(*CONDITION_SET_REQUEST_PARAMS)
          check_condition_set_values_params(params[cname][:conditions][key])
        end
      end
    end

    def check_condition_set_values_params(condition_params)
      %i[ticket contact company].each do |key|
        next unless condition_params[key].is_a?(Array)
        condition_params[key].map do |condition|
          values = *condition[:value]
          condition.permit(*CONDITION_SET_REQUEST_VALUES) if condition.is_a?(Hash)
          condition = convert_tag_fields(condition) if condition[:field_name] == TAG_NAMES && key == :ticket
          condition[:field_name] = 'ticlet_cc' if condition[:field_name] == 'ticket_cc' && key == :ticket
        end
      end
    end

    def set_automations_fields
      @condition_data = @item.condition_data || {}
      @match_type = @item.supervisor_rule? ? ((@conditions.present? && @conditions[:condition_set_1]['match_type']) || 
                                               @item.match_type || 
                                               DEFAULT_OPERATOR) : @item.match_type
      automation_fields = AUTOMATION_FIELDS[VAConfig::RULES_BY_ID[params[:rule_type].to_i]]
      automation_fields.each do |field_name|
        safe_send("set_#{field_name}_data")
      end
      set_conditions
    end

    def set_actions_data
      @item.action_data = construct_actions_data if @actions.present?
    end

    def set_conditions_data
      if @conditions.blank?
        @condition_data.merge!(conditions: @item.condition_data[:conditions]) if @item.observer_rule?
        return
      end
      @nested_conditions = construct_condition_data
      if @item.supervisor_rule?
        @filter_data = @nested_conditions
      elsif @item.observer_rule?
        @condition_data.merge!(conditions: @nested_conditions)
      else
        @condition_data = @nested_conditions
      end
    end

    def set_events_data
      @condition_data.merge!(events: construct_events_data) if @events.present?
    end

    def set_performer_data
      @condition_data.merge!(performer: construct_performer_data) if @performers.present?
    end

    def set_conditions
      if @item.supervisor_rule?
        @item.match_type = @match_type
        @item.filter_data = @filter_data if @filter_data.present?
      else
        @item.condition_data = @condition_data if @condition_data.present?
      end
    end

    def construct_performer_data
      @performers[:type] = @performers[:type].to_s
      @performers
    end

    def construct_events_data
      @events.map do |event|
        PERMITTED_EVENTS_PARAMS.inject({}) do |hash, key|
          is_key_present = event.key?(key)
          event_value = event[key]
          hash.merge!(construct_data(key.to_sym, event_value, is_key_present, EVENT_NESTED_FIELDS, true, true))
          key.to_s == 'from_nested_field' && is_key_present ? hash.merge!(construct_from_nested_rules(event)) : hash
        end
      end
    end

    def construct_from_nested_rules(event)
      nested_rule = event[:from_nested_field].each.map do |key, value|
        {
          name: value[:field_name],
          from: value[:value],
          to: event[:to_nested_field][key][:value]
        }
      end
      { nested_rule: nested_rule }
    end

    def construct_action_nested_fields(action)
      action_hash = {
        category_name: "#{action[:field_name]}_#{Account.current.id}",
        name: 'set_nested_fields'
      }
      (PERMITTED_ACTIONS_PARAMS - %i[field_name]).each do |key|
        action_hash.merge!(construct_data(key.to_sym, action[key], action.key?(key), CONDITON_SET_NESTED_FIELDS))
      end
      action_hash
    end

    def construct_webhook(action)
      action = action.dup
      action_hash = {
        content_type: Va::Constants::WEBHOOK_CONTENT_TYPES_ID[action[:content_type]].to_s,
        content_layout: action[:content_layout].to_s,
        request_type: Va::Constants::WEBHOOK_REQUEST_TYPES_ID[action[:request_type]].to_s,
        params: action[:content],
        url: action[:url],
        name: action[:field_name]
      }
      if action[:auth_header].present?
        action_hash[:need_authentication] = "true"
        action_hash[:username] = action[:auth_header][:username] if action[:auth_header][:username].present?
        action_hash[:password] = action[:auth_header][:password] if action[:auth_header][:password].present?
        action_hash[:api_key] = action[:auth_header][:api_key] if action[:auth_header][:api_key].present?
      end
      action_hash
    end

    def construct_data(key, value, has_key = true, nested_field_names = nil, is_ticket = false, is_event = false)
      original_key = key
      key = DB_FIELD_NAME_CHANGE_MAPPING[key] if DB_FIELD_NAME_CHANGE.include?(key)
      value = construct_nested_fields_data(value) if
            nested_field_names.present? && nested_field_names.include?(key)
      if is_event && value.present? && TRANSFORMABLE_EVENT_FIELDS.include?(original_key.to_sym) && !DEFAULT_EVENT_TICKET_FIELDS.include?(value.to_sym)
        field = current_account.ticket_fields_from_cache.find { |tf| tf.name ==  "#{value}_#{Account.current.id}" }
        value = field.column_name if field.present?
      end
      if key == :name
        value = "#{value}_#{Account.current.id}" if !DEFAULT_FIELDS.include?(value.to_sym) && is_ticket && !is_event
        value = "cf_#{value}" if !is_ticket && !COMPANY_FIELDS.include?(value.to_sym) && !CONDITION_CONTACT_FIELDS.include?(value.to_sym)
        value = SUPERVISOR_FIELD_MAPPING[value.to_sym] if @item.supervisor_rule? && SUPERVISOR_FIELD_MAPPING.key?(value.to_sym)
      end
      has_key ? { key => value } : {}
    end

    def construct_actions_data
      @actions.map do |action|
        if action.key?(:nested_fields)
          construct_action_nested_fields(action)
        elsif action[:field_name].to_sym == :trigger_webhook
          construct_webhook(action)
        else
          PERMITTED_ACTIONS_PARAMS.inject({}) do |hash, key|
            action[:value] = transform_add_tag_field(action) if action[:field_name].to_sym == :add_tag
            hash.merge!(construct_data(key.to_sym, action[key], action.key?(key), nil, true))
          end
        end
      end
    end

    def transform_add_tag_field(action)
      action[:value].is_a?(String) ? action[:value] : action[:value]*','
    end

    def construct_condition_data
      operator = (@conditions[:operator] || 'and').to_sym
      operator = MAP_CONDITION_SET_OPERATOR[operator]
      condition_sets = construct_condition_sets
      condition_sets.count > 1 ? { operator.to_sym => condition_sets } : condition_sets[0]
    end

    def construct_condition_sets
      %i[condition_set_1 condition_set_2].inject([]) do |condition_sets, key|
        if @conditions.key?(key)
          condition_sets.push(construct_condition_set(@conditions[key]))
        else
          condition_sets
        end
      end
    end

    def construct_condition_set(condition_set)
      operator = condition_set['match_type'] || DEFAULT_OPERATOR
      conditions = EVALUATE_ON_MAPPING.keys.inject([]) do |condition_array, evaluate_on|
        if condition_set[evaluate_on].present?
          condition_array.push(*construct_condition(condition_set[evaluate_on], evaluate_on))
        else
          condition_array
        end
      end
      @item.supervisor_rule? ? conditions : { operator.to_sym => conditions } 
    end

    def construct_condition(condition_set, evaluate_on)
      evaluate_on = EVALUATE_ON_MAPPING[evaluate_on] || evaluate_on
      condition_set.map do |condition|
        PERMITTED_CONDITION_SET_VALUES.inject({}) do |hash, key|
          is_ticket = evaluate_on == :ticket
          hash.merge!(evaluate_on: evaluate_on) unless @item.supervisor_rule?
          hash.merge!(construct_data(key.to_sym, condition[key], condition.key?(key), CONDITON_SET_NESTED_FIELDS, is_ticket))
        end
      end
    end

    def construct_nested_fields_data(nested_values)
      nested_values && nested_values.each.map do |nested_key, nested_value|
        PERMITTED_NESTED_DATA_PARAMS.inject({}) do |hash, key|
          hash.merge!(construct_data(key.to_sym, nested_value[key], nested_value.key?(key), nil, true))
        end
      end
    end

    def convert_tag_fields(condition)
      condition[:field_name] = 'tag_ids'
      condition[:value] = convert_tag_name_to_id(condition[:value])
      condition
    end

    def convert_tag_name_to_id(*values)
      converted = []
      values.flatten.each do |val|
        tag = Account.current.tags.find_by_name(val)
        value = tag.present? ? tag.id : val
        converted << value
      end
      converted
    end
end
