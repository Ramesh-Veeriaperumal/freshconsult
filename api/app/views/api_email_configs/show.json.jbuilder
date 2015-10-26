json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, :product_id, :created_at, :updated_at
end
