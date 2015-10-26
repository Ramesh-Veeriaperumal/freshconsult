json.array! @items do |business_calendar|
  json.cache! CacheLib.key(business_calendar, params) do
    json.extract! business_calendar, :id, :name, :description, :created_at, :updated_at
  end
end
