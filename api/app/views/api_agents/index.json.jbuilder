json.array! @items do |agent|
  json.cache! [controller_name, action_name, agent] do
    json.set! :available_since, agent.active_since

    json.(agent, :available, :created_at)

    json.set! :id, agent.user.id

    json.(agent, :occasional, :signature, :signature_html)
    
    json.set! :ticket_scope, agent.ticket_permission

    json.(agent, :updated_at)

    json.set! :user do
      json.(agent.user, :active, :created_at, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone, :updated_at)
    end
  end
end
