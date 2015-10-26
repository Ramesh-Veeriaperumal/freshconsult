json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :created_at, :updated_at
end
