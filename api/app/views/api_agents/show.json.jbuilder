json.cache! [controller_name, action_name, @item] do
  json.(@item, :available, :occasional, :signature, :signature_html)
  json.set! :id, @item.user_id
  json.set! :ticket_scope, @item.ticket_permission
  json.partial! 'shared/utc_date_format', item: @item, add: { active_since: :available_since}
  json.set! :user do
    json.(@item.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone)
    json.partial! 'shared/utc_date_format', item: @item.user
  end
end
