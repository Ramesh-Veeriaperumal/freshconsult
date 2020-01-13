module Admin::SkillHelper
  include Admin::SkillConstants

  private

    def check_skill_condition_params
      params[cname].permit(*REQUEST_PERMITTED_PARAMS)
      params[cname][:conditions].each { |cond| cond.permit(*CONDITION_PARAMS) } if params[cname][:conditions].present?
    end

    def set_skill_fields
      skill_fields = REQUEST_PERMITTED_PARAMS
      skill_fields.each do |field_name|
        safe_send(:"set_#{field_name}_data") if params[cname].present? && params[cname][field_name].present?
      end
    end

    def set_name_data
      @item.name = @name
    end

    def set_rank_data
      @item.position = @rank
    end

    def set_match_type_data
      @item.match_type = @match_type || DEFAULT_MATCH_TYPE
    end

    def set_agents_data
      @item.user_ids = @agents.map { |agent| agent[:id] }
    end

    def set_conditions_data
      @item.filter_data = construct_conditions
    end

    def construct_conditions
      @conditions.inject([]) { |result, condition| result << construct_condition(condition) }
    end

    def construct_condition(condition)
      condition_data = CONDITION_PARAMS.inject({}) do |hash, key|
        value = construct_condition_field(condition, key)
        hash.merge!(FIELD_NAME_CHANGE_MAPPINGS_INVERT[key] => value)
      end
      custom_field = ticket_fields.find { |tf| tf.name == condition[:field_name] + "_#{current_account.id}" }
      if condition[:nested_fields].present? || (custom_field.present? && custom_field.dom_type.to_sym == :nested_field)
        construct_nested_fields(condition, condition_data)
        nested_field_support(custom_field, condition, condition_data)
      end
      condition_data
    end

    def construct_condition_field(condition, key)
      case key
      when :resource_type
        EVALUATE_ON_MAPPINGS_INVERT[condition[key].try(:to_sym) || DEFAULT_RESOURCE_TYPE].to_s
      when :nested_fields
        condition[key].present? ? construct_nested_rules(condition[key]) : nil
      when :field_name
        append_account_id = condition[:resource_type].try(:to_sym) == :ticket &&
            custom_ticket_field_names(CUSTOM_FIELDS_FOR_SKILLS).include?(condition[key])
        append_account_id ? condition[key] + "_#{current_account.id}" : condition[key]
      else
        condition[FIELD_NAME_CHANGE_MAPPINGS[key].try(:to_s)] || condition[key]
      end
    end

    def construct_nested_fields(condition, condition_data)
      condition_data.merge!(rule_type: 'nested_rule')
      value = construct_condition_field(condition, :nested_fields)
      condition_data.merge!(nested_rules: value) if value.present?
    end

    def nested_field_support(custom_field, condition, condition_data)
      # for backward compatibility
      # saving child levels with same value of parent value
      if ANY_NONE.include?(condition[:value])
        condition_data[:nested_rules] ||= []
        custom_field.child_levels.pluck_all(:name).each do |field_name|
          condition_data[:nested_rules] << { name: field_name, value: condition[:value] }
        end
      elsif condition[:nested_fields].present? && ANY_NONE.include?(condition[:nested_fields][:level2][:value]) &&
          custom_field.child_levels.pluck_all(:name)[1].present?
        condition_data[:nested_rules][1] = { name: custom_field.child_levels.pluck_all(:name)[1],
                                             value: condition[:nested_fields][:level2][:value] }
      end
    end

    def construct_nested_rules(nested_fields)
      nested_fields.inject([]) { |result, fields| result << construct_nested_level(fields[1]) }
    end

    def construct_nested_level(nested_level)
      level = {}
      nested_level.each_pair do |field, value|
        field_name = FIELD_NAME_CHANGE_MAPPINGS_INVERT[field.to_sym]
        val = field_name == :name ? value + "_#{current_account.id}" : value
        level.merge!(field_name || field.to_sym => val)
      end
      level
    end

    def current_account
      @current_account ||= Account.current
    end

    def ticket_fields
      @ticket_fields ||= current_account.ticket_fields_from_cache
    end

    def agent_user_ids
      @agent_user_ids ||= current_account.agents_details_from_cache.map(&:id)
    end

    def custom_ticket_field_names(*field_types)
      ticket_fields.select { |tf| field_types.flatten.include?(tf.field_type.to_sym) }.map(&:name).map do |field_name|
        field_name.chomp("_#{current_account.id}")
      end
    end
end