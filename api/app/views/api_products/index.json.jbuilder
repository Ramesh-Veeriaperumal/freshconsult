json.array! @items do |product|
  json.cache! CacheLib.key(product, params) do
    json.extract! product, :id, :name, :description, :created_at, :updated_at
  end
end
