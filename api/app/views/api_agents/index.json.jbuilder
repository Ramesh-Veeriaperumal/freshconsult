json.array! @items do |agent|
  json.cache! CacheLib.compound_key(agent, agent.user, params) do
    json.extract! agent, :available, :occasional, :signature_html, :created_at, :updated_at
    json.set! :id, agent.user_id
    json.set! :available_since, agent.active_since
    json.set! :ticket_scope, agent.ticket_permission
    json.set! :user do
      json.extract! agent.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone, :created_at, :updated_at
    end
  end
end
