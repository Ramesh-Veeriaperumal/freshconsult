json.array! @items do |email_config|
  json.cache! CacheLib.key(email_config, params) do
    json.extract! email_config, :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, :product_id, :created_at, :updated_at
  end
end
