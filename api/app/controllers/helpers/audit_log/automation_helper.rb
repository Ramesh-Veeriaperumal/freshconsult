module AuditLog::AutomationHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::AutomationRule

  ALLOWED_MODEL_CHANGES = [:name, :description, :match_type, :active, :position,
                           :filter_data, :action_data, :condition_data].freeze

  def automation_rule_changes(_model_data, changes)
    response = []
    set_rule_type(_model_data[:rule_type])
    changes = readable_rule_changes(changes)
    model_name = :automation_rule
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
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

  def condition_data_changes(value)
    if observer_rule?
      changes = []
      model_name = :automation_rule
      value[0].each_pair do |key, val|
        trans_k = translated_key(key, model_name)
        changes << case key
                   when :performer
                    result = filter_action_changes(trans_k, [[value[0][key]].flatten, [value[1][key]].flatten])
                    result.present? ? result : []
                   when :events
                    result = filter_action_changes(trans_k, [[value[0][key]].flatten, [value[1][key]].flatten])
                    next unless result.present?
                    result
                   when :conditions
                    filter_condition_data_changes(value[0][key], value[1][key])
                   end
      end
      changes
    else
      filter_condition_data_changes(value[0], value[1])
    end
  end

  def filter_condition_data_changes(old_condition, new_condition)
    result = []
    was_single_set = old_condition.first[1][0].key?(:evaluate_on)
    is_single_set = new_condition.first[1][0].key?(:evaluate_on)
    case condition_set_case_mapping(is_single_set, was_single_set)
    when :single_sets
      result << fetch_condition_changes([old_condition.values.flatten, new_condition.values.flatten],
                                        [old_condition.keys.first, new_condition.keys.first], 0)
    when :set_added
      operator_changes = toggle_operator(["", new_condition.keys.first])
      result << operator_changes if operator_changes.present?
      result << condition_sets_updated(old_condition, new_condition, true)
    when :set_removed
      operator_changes = toggle_operator([old_condition.keys.first, ""])
      result << operator_changes if operator_changes.present?
      result << condition_sets_updated(old_condition, new_condition)
    else
      operator_changes = toggle_operator([old_condition.keys.first, new_condition.keys.first])
      result << operator_changes if operator_changes.present?
      result << filter_condition_sets(old_condition, new_condition)
    end
    result
  end

  def filter_condition_sets(old_condition, new_condition)
    result = []
    2.times do |set|
      changes = fetch_condition_changes([old_condition.first[1][set].first[1],
                                         new_condition.first[1][set].first[1]],
                                        [old_condition.first[1][set].first[0],
                                         new_condition.first[1][set].first[0]], set)
      result << changes if changes.present?
    end
    result
  end

  def condition_sets_updated(old_condition, new_condition, added = false)
    # Example:
    # old_condition = {:any=>[{:evaluate_on=>"ticket", :name=>"Agent", :operator=>"in", :value=>"None"}]}
    # new_condition = {:any=>[{:all=>[{:evaluate_on=>"ticket", :name=>"Priority", :operator=>"in", :value=>""}]},
    #                  {:all=>[{:evaluate_on=>"ticket", :name=>"Subject or Description", :operator=>"is", :value=>"test"}]}]}
    # Or vice-versa depending on 'added'

    result = []
    updated_set = added ? old_condition.first[1] : new_condition.first[1]
    updated_match_type = added ? old_condition.first[0] : new_condition.first[0]
    2.times do |set|
      if added
        match_type = new_condition.first[1][set].first[0]
        conditions = [updated_set, new_condition.first[1][set].first[1]]
        match_types = [updated_match_type, match_type]
      else
        match_type = old_condition.first[1][set].first[0]
        conditions = [old_condition.first[1][set].first[1], updated_set]
        match_types = [match_type, updated_match_type]
      end
      changes = fetch_condition_changes(conditions, match_types, set)
      result << changes if changes.present?
      updated_set = []
      updated_match_type = ""
    end
    result
  end

  def fetch_condition_changes(conditions, match_type, set)
    result = []
    condition_key = translated_key("condition_set_#{set+1}".to_sym,:automation_rule)
    match_type_key = translated_key("match_type_#{set+1}".to_sym, :automation_rule)
    changes = filter_action_changes(condition_key, [conditions[0], conditions[1]])
    result << changes if changes.present?
    result << description_properties(match_type_key, [match_type[0], match_type[1]],
                                     { type: :default }) if match_type[0] != match_type[1]
    result
  end

  def toggle_operator(values)
    trans_key = translated_key(:operator, :automation_rule)
    values[0] != values[1] ? description_properties(trans_key, [translate_operator(values[0]),
                                                                translate_operator(values[1])], type: :default) : nil
  end

  def translate_operator(value)
    return value if value.blank?
    value == :any ? 'or' : 'and'
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
