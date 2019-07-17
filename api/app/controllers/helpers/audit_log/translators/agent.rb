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
          levels.find { |level| level.id == model_changes[attribute][0] }.try(:name).to_s,
          levels.find { |level| level.id == model_changes[attribute][1] }.try(:name).to_s
        ]
      when :available
        model_changes[attribute] = [
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][0]],
          AuditLogConstants::TOGGLE_ACTIONS[model_changes[attribute][1]]
        ]
      when :misc_changes
        valid_action_and_name = login_logout_action?(model_changes[:misc_changes])
        model_changes[valid_action_and_name[1]] = '' if valid_action_and_name[0]
      end
    end
    model_changes
  end

  def levels
    @levels ||= Account.current.scoreboard_levels.all
  end

  def login_logout_action?(misc_changes)
    misc_changes.each do |key, value|
      if key.eql? :logged_in
        return misc_changes[:logged_in][0]? Agent::AGENT_LOGIN_LOGOUT_ACTIONS[1] : Agent::AGENT_LOGIN_LOGOUT_ACTIONS[0]
      end
    end
    [false, '']
  end
end
