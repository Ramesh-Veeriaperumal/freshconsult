module AuditLog::AutomationHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::AutomationRule

  ALLOWED_MODEL_CHANGES = [:name, :description, :active, :position, :action_data].freeze

  CONDITION_SET_COUNT = 2

  def automation_rule_changes(_model_data, changes)
    response = []
    set_rule_type(_model_data[:rule_type])
    changes = readable_rule_changes(changes)
    model_name = :automation_rule
    changes.each_pair do |key, value|
      next unless (ALLOWED_MODEL_CHANGES + filter_data).include?(key)

      trans_key = translated_key(key, model_name)
      response << case key
                  when :filter_data
                    if value.first.is_a?(Array)
                      result = filter_action_changes(trans_key, value)
                      next unless result.present?
                      result
                    else
                      res = []
                      value.first.each do |k, v|
                        trans_k = translated_key(k, model_name)
                        result = filter_action_changes(trans_k,
                                                       [[value.first[k]].flatten, [value.last[k]].flatten])
                        res.push(result) if result.present?
                      end
                      res
                    end
                  when :condition_data
                    result = condition_data_changes(value)
                    next unless result.present?
                    result
                  when :action_data
                    result = filter_action_changes(trans_key, value)
                    next unless result.present?
                    result
                  else
                    description_properties(trans_key, value)
                  end
    end
    response.flatten
  end

  private

  def filter_data
    !supervisor_rule? ? %i[condition_data] : %i[match_type filter_data]
  end

  def condition_data_changes(value)
    if observer_rule?
      changes = []
      model_name = :automation_rule
      value[0].each_pair do |key, val|
        trans_k = translated_key(key, model_name)
        changes << case key
                   when :performer
                     filter_action_changes(trans_k, [[value[0][key]].flatten, [value[1][key]].flatten])
                   when :events
                     filter_action_changes(trans_k, [[value[0][key]].flatten, [value[1][key]].flatten])
                   when :conditions
                     filter_condition_changes(value[0][key], value[1][key])
                   end
      end
      changes
    else
      filter_condition_changes(value[0], value[1])
    end
  end

  def filter_condition_changes(old_condition, new_condition)
    result = []
    operator_changes = filter_operator_changes(old_condition, new_condition)
    result << operator_changes if operator_changes.present?
    old_match_types, new_match_types = [fetch_match_types(old_condition), fetch_match_types(new_condition)]
    match_type_changes = filter_match_type_changes(old_match_types, new_match_types)
    result << match_type_changes if match_type_changes.present?
    old_conditions, new_conditions = [fetch_conditions(old_condition), fetch_conditions(new_condition)]
    condition_changes = filter_condition_set_changes(old_conditions, new_conditions)
    result << condition_changes if condition_changes.present?
    result
  end

  def filter_operator_changes(old_condition, new_condition)
    old_operator = if condition_present?(old_condition)
                     single_set?(old_condition) ? '' : old_condition.first[0]
                   else
                     ''
                   end
    new_operator = if condition_present?(new_condition)
                     single_set?(new_condition) ? '' : new_condition.first[0]
                   else
                     ''
                   end
    toggle_operator([old_operator, new_operator])
  end

  def fetch_match_types(conditions)
    return '' unless condition_present?(conditions)

    if single_set?(conditions)
      [translate_match_type(conditions.first[0])]
    else
      conditions.first[1].map(&:keys).flatten.map { |match_type| translate_match_type(match_type) }
    end
  end

  def filter_match_type_changes(old_match_types, new_match_types)
    result = []
    CONDITION_SET_COUNT.times do |set|
      old_match_type = old_match_types[set] || ''
      new_match_type = new_match_types[set] || ''
      match_type_key = translated_key("match_type_#{set + 1}".to_sym, :automation_rule)
      result << description_properties(match_type_key, [old_match_type, new_match_type],
                                       type: :default) if old_match_type != new_match_type
    end
    result
  end

  def fetch_conditions(conditions)
    return [] unless condition_present?(conditions)

    if single_set?(conditions)
      [conditions.first[1]]
    else
      condition_sets = conditions.first[1].map(&:values)
      [condition_sets[0].flatten, condition_sets[1].flatten]
    end
  end

  def filter_condition_set_changes(old_conditions, new_conditions)
    result = []
    CONDITION_SET_COUNT.times do |set|
      old_condition = old_conditions[set] || []
      new_condition = new_conditions[set] || []
      condition_key = translated_key("condition_set_#{set + 1}".to_sym, :automation_rule)
      changes = filter_action_changes(condition_key, [old_condition, new_condition])
      result << changes if changes.present?
    end
    result
  end

  def toggle_operator(values)
    trans_key = translated_key(:operator, :automation_rule)
    values[0] != values[1] ? description_properties(trans_key, [translate_conditions_operator(values[0]),
                                                                translate_conditions_operator(values[1])], type: :default) : nil
  end

  def toggle_status(value)
    value.map { |toggle_stats| toggle_stats ? 1 : 0 }
  end

  def automation_rule?(rule_type)
    AuditLogConstants::AUTOMATION_RULE_TYPES.include?(rule_type)
  end

  def filter_action_changes(key, value)
    changed_value = []
    return [] if !(value.first - value.last).present? && !(value.last - value.first).present?
    changed_value << condition_changes((value.first - value.last), "Removed")
    changed_value << condition_changes((value.last - value.first), "Added")
    description_properties(key, changed_value, type: :array)
  rescue Exception => e
    nil
  end

  def condition_changes(changes, action)
    conditions = []
    changes.each do |condition|
      condition[:value] = sanitize_audit_log_value(condition[:value]) if condition[:value].present?
      conditions << description_properties(condition[:name], 
                                           nil, 
                                           condition.except(:name))
    end
    description_properties(action, conditions, type: :array)
  end

  alias dispatcher_changes automation_rule_changes
  alias dispatcher_rule_changes automation_rule_changes
  alias observer_changes automation_rule_changes
  alias supervisor_changes automation_rule_changes
end
