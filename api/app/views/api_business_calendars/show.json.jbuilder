json.cache! @item do
  json.(@item, :id, :name, :description, :time_zone)
  json.partial! 'shared/boolean_format', boolean_fields: { is_default: @item.is_default }
  json.partial! 'shared/utc_date_format', item: @item
end
