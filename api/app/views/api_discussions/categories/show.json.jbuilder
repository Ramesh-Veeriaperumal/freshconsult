json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :position
  json.partial! 'shared/utc_date_format', item: @item
end
