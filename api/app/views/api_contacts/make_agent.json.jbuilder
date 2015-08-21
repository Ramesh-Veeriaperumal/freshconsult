json.(@agent.user, :active, :email, :job_title, :language, :mobile, :name, :phone, :time_zone)

json.partial! 'shared/utc_date_format', item: @agent.user

json.set! :agent do
  json.set! :available_since, @agent.active_since

  json.(@agent, :available, :created_at)

  json.set! :id, @agent.user.id

  json.(@agent, :occasional, :signature, :signature_html)

  json.set! :ticket_scope, @agent.ticket_permission

  json.(@agent, :updated_at)
end