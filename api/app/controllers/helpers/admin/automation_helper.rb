# This Admin::AutomationHelper is helper for automations_controller
module Admin::AutomationHelper
  include Admin::AutomationConstants
  include Va::Constants
  include Admin::Automation::ConstructData
  private

    def check_automation_params
      params[cname].permit(*PERMITTED_PARAMS)
      %i[performer events conditions actions].each do |key|
        safe_send(:"check_#{key}_params") if params[cname].present? && params[cname][key].present?
      end
    end

    def check_conditions_params
      params[cname][:conditions].each do |condition|
        condition.permit(*CONDITION_SET_DEFAULT_PARAMS)
        check_condition_set_values_params(condition[:properties])
      end
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

    def check_condition_set_values_params(condition_params)
      condition_params.map do |condition|
        CONDITION_RESOURCE_TYPES.each do |key|
          condition.permit(*CONDITION_SET_REQUEST_VALUES) if condition.is_a?(Hash)
          condition = convert_tag_fields(condition) if condition[:field_name] == TAG_NAMES && key == :ticket
          condition[:value] = condition[:value].map { |val| val == ANY_NONE[:ANY] ? -1 : val } if condition[:field_name] == RESPONDER_ID && key == :ticket
          condition[:field_name] = 'ticlet_cc' if condition[:field_name] == 'ticket_cc' && key == :ticket
          condition[:field_name] = condition[:field_name].to_s + '_' + condition[:custom_status_id].to_s if condition[:field_name].to_s == TIME_AND_STATUS_BASED_FILTER[0] && key == :ticket
          condition[:nested_fields].permit(*LEVELS).values.each { |value| value.permit(*PERMITTED_DEFAULT_CONDITION_SET_VALUES) } if condition.key?(:nested_fields)
          check_related_condition(condition[:related_conditions]) if condition.key?(:related_conditions)
          add_case_sensitive_key(condition) if condition.present?
        end
      end
    end

    def check_related_condition(related_conditions)
      related_conditions.each do |related_condition|
        related_condition.permit(*PERMITTED_RELATED_CONDITION_SET_VALUES)
        check_related_condition(related_condition[:related_conditions]) if related_condition.key?(:related_conditions)
      end
    end

    def add_case_sensitive_key(data)
      data[:case_sensitive] ||= false and return if DEFAULT_TEXT_FIELDS.include?(data[:field_name].to_sym)
      field = ticket_fields.find { |tf| tf.name == "#{data[:field_name]}_#{current_account.id}" }
      data[:case_sensitive] ||= false if field.present? && CUSTOM_TEXT_FIELD_TYPES.include?(field.field_type.to_sym)
    end

    def set_automations_fields
      @condition_data = @item.condition_data || {}
      @match_type = @item.supervisor_rule? ? ((@conditions.present? && @conditions.first['match_type']) ||
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
      if @conditions.blank? && @operator.blank?
        @condition_data.merge!(conditions: (@item.condition_data.present? && 
                                            @item.condition_data[:conditions]) || 
                                           {:all=>[]}) if @item.observer_rule?
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
      result = []
      @events.each do |event|
        next if event.blank? || !event.is_a?(Hash)
        event = event.deep_symbolize_keys
        field_name = event[:field_name]
        next if field_name.blank? || !field_name.is_a?(String)
        field_name = field_name.to_sym
        if DEFAULT_EVENT_TICKET_FIELDS.include?(field_name) || SYSTEM_EVENT_FIELDS.include?(field_name)
          event_data = default_field_data(event)
        else
          tf = ticket_field_by_name(field_name)
          next if tf.blank?
          event_data = custom_field_event_data(tf, event)
        end
        result << event_data
      end
      result
    end

    def default_field_data(field)
      field_data = {}
      field_data[:name] = field[:field_name]
      field_hash =  EVENT_FIELDS_HASH.find {|field_hash| field_hash[:name] == field[:field_name].to_sym }
      if field_hash[:expect_from_to]
        field_data[:from] = field[:from]
        field_data[:to] = field[:to]
      else
        field_data[:value] = field[:value] unless field_hash[:field_type] == :label
      end
      field_data
    end

    def custom_field_event_data(tf, event)
      event_data = {}
      if tf[:field_type] == 'nested_field'
        event_data = construct_nested_field_rule(event, tf, true)
      elsif tf[:field_type] == "custom_checkbox"
        event_data[:name] = tf.column_name
        event_data[:value] = event[:value].to_s
      else
        event_data[:name] = tf.column_name
        event_data[:from] = event[:from]
        event_data[:to] = event[:to]
      end
      event_data
    end

    def construct_nested_field_rule(field, tf, is_event = false)
      if is_event
        data = _event_nested_rule(tf, field)
      else
        data = {}
        data[:name] = tf[:name]
        data[:value] = field[:value]
        data[:rule_type] = 'nested_rule'
        data[:nested_rules] = _nested_data(field[:nested_field], tf.id, is_event, _any_none(data[:value]))
      end
      data
    end

    def _event_nested_rule(tf, field)
      data = {}
      data[:name] = tf[:column_name]
      data[:from] = field[:from]
      data[:to] = field[:to]
      data[:rule_type] = ['nested_rule'] * 2
      data[:from_nested_rules] = _nested_data(field[:from_nested_field], tf[:id],true, _any_none(data[:from]))
      data[:to_nested_rules] = _nested_data(field[:to_nested_field], tf[:id], true, _any_none(data[:to]))
      data[:nested_rule] = merge_arrays_of_hash(transform_hash_key(data[:from_nested_rules], [:value], [:from]),
                                                 transform_hash_key(data[:to_nested_rules], [:value], [:to]))
      data
    end

    def _nested_data(field, parent_id, is_event, parent_value)
      data = []
      NESTED_LEVEL_COUNT.times.each do |_level_num|
        nested_field = find_nested_field_by_level(parent_id, _level_num + NESTED_LEVEL_COUNT)
        next if nested_field.blank?

        level = field.try(:[], :"level#{_level_num + NESTED_LEVEL_COUNT}")
        value = level.try(:[], :value) || parent_value || "" # in case of only two value in nested field
        name = is_event ? nested_field.column_name : nested_field.name
        data << { name: name, value: value }
        # For 'level3' nested_filed the parent value should be the value of 'level2' nested_field.
        parent_value = _any_none(value)
      end
      data
    end

    def merge_arrays_of_hash(left, right)
      merged_arr = []
      left.each_with_index do |_l, index|
        merged_arr << _l.merge(right[index])
      end
      merged_arr
    end

    def transform_hash_key(data, old_key_names = [], new_key_names = [])
      return [] if data.blank?
      transformed_data = data.dup
      old_key_names.size.times do |index|
        transformed_data.map! do |_each_data|
          dup_data = _each_data.clone
          dup_data[new_key_names[index]] = dup_data.delete old_key_names[index]
          dup_data
        end
      end
      transformed_data
    end

    def _any_none(val)
      ANY_NONE_VALUES.find {|_value| _value == val }
    end

    def construct_from_nested_rules(event, event_key, from_nested_field, to_nested_field)
      nested_rule = from_nested_field.each.map do |key, value|
        field = ticket_field_by_name(value[:field_name])
        field_name = field.present? ? field.column_name : value[:field_name]
        initial_hash = { name: field_name }
        event_key != :nested_rule ? initial_hash.merge!({value: value[:value]}) : 
                                    initial_hash.merge!({from: value[:value],
                                                         to: to_nested_field[key][:value]})
      end
      { "#{event_key}": nested_rule }
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

    def construct_data(key, value, has_key = true, nested_field_names = nil, is_ticket = false, is_event = false)
      original_key = key
      key = DB_FIELD_NAME_CHANGE_MAPPING[key] if DB_FIELD_NAME_CHANGE.include?(key)
      value = construct_nested_fields_data(value) if
            nested_field_names.present? && nested_field_names.include?(key)
      value = construct_asssociated_fields_data(value) if key == :associated_fields && value.present?
      value = construct_related_conditions(value) if key == :related_conditions && value.present?
      if is_event && value.present? && 
         TRANSFORMABLE_EVENT_FIELDS.include?(original_key.to_sym) && 
         !value.is_a?(Array) &&
         !DEFAULT_EVENT_TICKET_FIELDS.include?(value.to_sym)
        field = ticket_fields.find { |tf| tf.name ==  "#{value}_#{Account.current.id}" }
        value = field.column_name if field.present?
      end
      if key == :name
        value = "#{value}_#{Account.current.id}" if !DEFAULT_FIELDS.include?(value.to_sym) && is_ticket && !is_event && (!value.to_s.include? TIME_AND_STATUS_BASED_FILTER[0])
        value = "cf_#{value}" if !is_ticket && !COMPANY_FIELDS.include?(value.to_sym) && !CONDITION_CONTACT_FIELDS.include?(value.to_sym)
        value = SUPERVISOR_FIELD_MAPPING[value.to_sym].to_s if @item.supervisor_rule? && SUPERVISOR_FIELD_MAPPING.key?(value.to_sym)
        name_changed = DISPLAY_FIELD_NAME_CHANGE[value.to_sym]
        value = name_changed if name_changed.present? &&  !@item.supervisor_rule?
      end
      has_key ? { key => value } : {}
    end

    def construct_actions_data
      @actions.map do |action|
        name = action[:field_name].to_sym
        if action.key?(:nested_fields)
          construct_action_nested_fields(action)
        elsif name == :trigger_webhook
          construct_webhook(action)
        elsif INTEGRATION_ACTION_FIELDS.include?(name)
          construct_marketplace_app(action)
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
      params_operator = @operator.present? ? @operator.split(' ')[1].to_sym : nil
      operator = MAP_CONDITION_SET_OPERATOR[params_operator] || @item.rule_operator.to_s || 'and'
      condition_sets = if @conditions.present?
                         @conditions.inject([]) { |result, condition| result << construct_condition_set(condition) }
                       else
                         @item.observer_rule? ? @item.condition_data[:conditions].first[1] : @item.condition_data.first[1]
                       end
      condition_sets.count > 1 ? { operator.to_sym => condition_sets } : condition_sets[0]
    end

    def construct_condition_set(condition_set)
      match_type = condition_set[:match_type] || DEFAULT_OPERATOR
      conditions = construct_condition(condition_set[:properties])
      @item.supervisor_rule? ? conditions : { match_type.to_sym => conditions }
    end

    def construct_condition(condition_set)
      condition_set.map do |condition|
        return {} if condition.blank?
        evaluate_on = EVALUATE_ON_MAPPING[condition[:resource_type].try(:to_sym)] || condition[:resource_type].try(:to_sym)
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

    def construct_asssociated_fields_data(associated_fields)
      PERMITTED_ASSOCIATED_FIELDS.inject({}) do |hash, key|
        hash.merge!(construct_data(key.to_sym, associated_fields[key], associated_fields.key?(key), nil, true))
      end
    end

    def construct_related_conditions(related_conditions)
      result = []
      related_conditions.each do |agent_shift|
        res = construct_asssociated_fields_data(agent_shift)
        res[:related_conditions] = agent_shift[:related_conditions].each.map { |r| construct_asssociated_fields_data(r) } if agent_shift.key?(:related_conditions)
        result << res
      end
      result
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

    def ticket_fields
      @ticket_fields ||= current_account.ticket_fields_from_cache
    end

    def event_ticket_fields
      @event_tfs ||= current_account.event_flexifields_with_ticket_fields_from_cache
    end

    def find_nested_field_by_level(parent_id, level)
      ticket_fields.find { |tf| tf[:parent_id] == parent_id && tf[:level] == level}
    end

    def ticket_field_by_name(field_name)
      ticket_fields.find { |tf| tf.name ==  "#{field_name}_#{Account.current.id}" }
    end
end
