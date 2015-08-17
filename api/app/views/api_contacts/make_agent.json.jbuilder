json.cache! @agent do
  json.(@agent.user, :active, :address, :client_manager, :company_id, :description, :email, :helpdesk_agent, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :deleted)

  json.partial! 'shared/utc_date_format', item: @agent.user

  json.set! :agnet do
    json.(@agent, :active_since, :available, :created_at, :id, :occasional, :points, :scoreboard_level_id, :signature, :signature_html, :ticket_permission, :updated_at)
  end
end
