module AuditLog::AgentHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::Agent

  ALLOWED_MODEL_CHANGES = [:email, :roles, :single_access_token, :ticket_permission,
                           :available, :occasional, :logged_in, :logged_out].freeze

  def agent_changes(_model_data, changes)
    response = []
    changes = readable_agent_changes(changes)
    model_name = :agent
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)
      trans_key = translated_key(key, model_name)
      response.push key == :roles ? 
        nested_description(trans_key, value, :agent) :
        description_properties(trans_key, value)
    end
    response
  end
end
