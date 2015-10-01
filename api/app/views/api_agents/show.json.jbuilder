json.cache! CacheLib.compound_key(@item, @item.user, params) do
  json.extract! @item, :available, :occasional, :signature, :signature_html
  json.set! :id, @item.user_id
  json.set! :ticket_scope, @item.ticket_permission
  json.partial! 'shared/utc_date_format', item: @item, add: { active_since: :available_since }
  json.set! :user do
    json.extract! @item.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone
    json.partial! 'shared/utc_date_format', item: @item.user
  end
end
