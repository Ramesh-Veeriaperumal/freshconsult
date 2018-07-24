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
      response.push key == :roles ? 
        nested_description(trans_key, value, :agent, { type: :link, path: '/a/admin/role' }) :
        description_properties(trans_key, value)
    end
    response
  end
end
