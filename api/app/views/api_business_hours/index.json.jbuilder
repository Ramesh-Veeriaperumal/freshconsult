json.array! @items do |business_hour|
  json.cache! CacheLib.key(business_hour, params) do
    json.extract! business_hour, :id, :name, :description
    json.partial! 'shared/utc_date_format', item: business_hour
  end
end
