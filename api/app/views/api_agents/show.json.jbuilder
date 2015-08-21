json.cache! [controller_name, action_name, @item] do
  json.set! :available_since, @item.active_since

  json.(@item, :available, :created_at)

  json.set! :id, @item.user.id

  json.(@item, :occasional, :signature, :signature_html)

  json.set! :ticket_scope, @item.ticket_permission

  json.(@item, :updated_at)

  json.set! :user do
    json.(@item.user, :active, :created_at, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone, :updated_at)
  end
end
