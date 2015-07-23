json.cache! @item do
  json.(@item, :id, :name, :description, :domains, :note)
  json.domains @item.api_domains
  json.partial! 'shared/utc_date_format', item: @item
end
json.custom_fields @item.custom_field
