json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :domains, :note
  json.partial! 'shared/utc_date_format', item: @item
end

json.custom_fields @item.custom_fields
