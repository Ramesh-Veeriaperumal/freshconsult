  json.cache! CacheLib.key(@api_product, params) do
    json.extract! @item, :id, :name, :description, :created_at, :updated_at
  end
