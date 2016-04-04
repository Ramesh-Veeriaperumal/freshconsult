json.cache! CacheLib.compound_key(@item, ApiConstants::CACHE_VERSION[:v2], @item.user, params) do
  json.extract! @item, :available, :occasional
  json.set! :id, @item.user_id
  json.set! :ticket_scope, @item.ticket_permission
  json.set! :signature, @item.signature_html
  json.partial! 'shared/utc_date_format', item: @item, add: { active_since: :available_since }
  json.set! :contact do
    json.extract! @item.user, :active, :email, :job_title, :language, :last_login_at, :mobile, :name, :phone, :time_zone
    json.partial! 'shared/utc_date_format', item: @item.user
  end
end
