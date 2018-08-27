module AuditLog::AutomationHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::AutomationRule

  ALLOWED_MODEL_CHANGES = [:name, :description, :match_type, :active, :position,
                           :filter_data, :action_data].freeze

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
