json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :time_zone, :is_default
  json.set! :business_hours, @item.business_intervals
  json.set! :holiday_list, @item.holiday_data
  json.partial! 'shared/utc_date_format', item: @item
end
