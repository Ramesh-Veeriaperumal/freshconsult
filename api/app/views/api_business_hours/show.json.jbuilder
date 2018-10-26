json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :time_zone, :is_default
  json.set! :business_hours, @item.business_intervals
  json.partial! 'shared/utc_date_format', item: @item
end
