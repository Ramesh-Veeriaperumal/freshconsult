module AuditLog::Translators::Agent
  def readable_agent_changes(model_changes)
    model_changes.keys.each do |attribute|
      case attribute
      when :ticket_permission
        model_changes[attribute] = [
          Agent::PERMISSION_KEYS_OPTIONS[model_changes[attribute][0]],
          Agent::PERMISSION_KEYS_OPTIONS[model_changes[attribute][1]]
        ]
      when :scoreboard_level_id
        model_changes[attribute] = [
          levels.find { |level| level.id == model_changes[attribute][0] }.name,
          levels.find { |level| level.id == model_changes[attribute][1] }.name
        ]
      when :available
        model_changes[attribute] = [
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][0]],
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][1]]
        ]
      end
    end
    model_changes
  end

  def levels
    @levels ||= Account.current.scoreboard_levels.all
  end
end
