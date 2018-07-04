module AuditLog::AutomationHelper
  include AuditLog::AuditLogHelper

  ALLOWED_MODEL_CHANGES = [:name, :description, :match_type, :active, :position].freeze

  def automation_rule_changes(_model_data, changes)
    response = []
    changes.deep_symbolize_keys
    model_name = :automation_rule
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
      trans_key = translated_key(key, model_name)
      response << case key
                  when :active
                    description_properties(trans_key,
                      translated_value(:AUTOMATION_RULE_TOGGLE, toggle_status(value)))
                  else
                    description_properties(trans_key, value)
                  end
    end
    response
  end

  alias dispatcher_changes automation_rule_changes
  alias dispatcher_rule_changes automation_rule_changes
  alias observer_changes automation_rule_changes
  alias supervisor_changes automation_rule_changes

  private

  def toggle_status(value)
    value.map { |toggle_stats| toggle_stats ? 1 : 0 }
  end

  def automation_rule?(rule_type)
    AuditLogConstants::AUTOMATION_RULE_TYPES.include?(rule_type)
  end
end
