json.array! @items do |agent|
  json.cache! CacheLib.compound_key(agent, ApiConstants::CACHE_VERSION[:v2], agent.user, params) do
    json.extract! agent, :available, :occasional
    json.set! :id, agent.user_id
    json.set! :signature, agent.signature_html
    json.set! :ticket_scope, agent.ticket_permission
    json.partial! 'shared/utc_date_format', item: agent, add: { active_since: :available_since }
    json.set! :contact do
      json.extract! agent.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone
      json.partial! 'shared/utc_date_format', item: agent.user
    end
  end
end
