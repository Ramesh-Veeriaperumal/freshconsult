json.array! @items do |business_calendar|
  json.cache! CacheLib.key(business_calendar, params) do
    json.extract! business_calendar, :id, :name, :description
    json.partial! 'shared/utc_date_format', item: business_calendar
  end
end
