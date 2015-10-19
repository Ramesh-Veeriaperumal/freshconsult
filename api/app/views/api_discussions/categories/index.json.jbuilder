json.array! @items do |fc|
  json.cache! CacheLib.key(fc, params) do
    json.extract! fc, :id, :name, :description, :position, :created_at, :updated_at
  end
end
