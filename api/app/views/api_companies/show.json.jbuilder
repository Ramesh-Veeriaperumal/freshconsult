json.cache! [controller_name, action_name, @item] do
  json.(@item, :id, :name, :description, :domains, :note)
  json.domains csv_to_array(@item.domains)
  json.partial! 'shared/utc_date_format', item: @item
end
json.custom_fields @item.custom_field
