json.array! @items do |agent|
  json.cache! CacheLib.compound_key(agent, agent.user, params) do
    json.extract! agent, :available, :occasional, :signature_html
    json.set! :id, agent.user_id
    json.set! :ticket_scope, agent.ticket_permission
    json.partial! 'shared/utc_date_format', item: agent, add: { active_since: :available_since }
    json.set! :user do
      json.extract! agent.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone
      json.partial! 'shared/utc_date_format', item: agent.user
    end
  end
end
