json.cache! CacheLib.compound_key(@item, ApiConstants::CACHE_VERSION[:v2], @item.user, params) do
  json.extract! @item, :available, :occasional
  json.set! :id, @item.user_id
  json.set! :ticket_scope, @item.ticket_permission
  json.set! :signature, @item.signature_html
  json.set! :group_ids, @item.group_ids
  json.set! :role_ids, @item.user.role_ids
  json.partial! 'shared/utc_date_format', item: @item, add: { active_since: :available_since }
  json.set! :contact do
    json.extract! @item.user, :active, :email, :job_title, :language, :mobile, :name, :phone, :time_zone
    json.partial! 'shared/utc_date_format', item: @item.user, add: { last_login_at: :last_login_at }
  end
end
