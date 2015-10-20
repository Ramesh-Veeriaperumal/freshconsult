json.array! @items do |fc|
  json.cache! CacheLib.key(fc, params) do
    json.extract! fc, :id, :name, :description, :created_at, :updated_at
  end
end
