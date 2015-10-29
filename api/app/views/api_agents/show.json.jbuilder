json.cache! CacheLib.compound_key(@item, @item.user, params) do
  json.extract! @item, :available, :occasional, :signature_html, :created_at, :updated_at
  json.set! :id, @item.user_id
  json.set! :available_since, @item.active_since
  json.set! :ticket_scope, @item.ticket_permission
  json.set! :user do
    json.extract! @item.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone, :created_at, :updated_at
  end
end
