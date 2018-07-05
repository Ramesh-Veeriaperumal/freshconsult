module AuditLog::AgentHelper
  include AuditLog::AuditLogHelper

  ALLOWED_MODEL_CHANGES = [:email, :roles, :single_access_token, :ticket_permission,
                           :available, :occasional].freeze

  def agent_changes(_model_data, changes)
    response = []
    changes.deep_symbolize_keys
    model_name = :agent
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
      trans_key = translated_key(key, model_name)
      response << case key
                  when :ticket_permission
                    ticket_permission_changes(trans_key, value)
                  when :scoreboard_level_id
                    scoreboard_level_changes(trans_key, value)
                  when :roles
                    link_options = { type: :link, path: '/a/admin/role' }
                    nested_description(trans_key, value, :agent, link_options)
                  when :available
                    description_properties(trans_key, 
                      translated_value(:AGENT_AVAILABILITY, available_status(value)))
                  else
                    description_properties(trans_key, value)
                  end
    end
    response
  end

  private

  def available_status(value)
    value.map do |available|
      available ? 1 : 0
    end
  end

  def ticket_permission_changes(key, value)
    description_properties(key, translated_value(:AGENT_TICKET_SCOPE, value))
  end

  def scoreboard_level_changes(key, value)
    @levels ||= Account.current.scoreboard_levels.all
    changed_level = @levels.map do |level|
      level.name if value.include?(level.id)
    end.compact
    if changed_level.present?
      changed_level = changed_level.reverse if value[0].to_i > value[1].to_i
    end
    description_properties(key, changed_level)
  end

end
