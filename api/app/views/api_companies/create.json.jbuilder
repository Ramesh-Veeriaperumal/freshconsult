json.(@item, :id, :name, :description, :note)
json.domains @item.api_domains
json.custom_fields @item.custom_field
json.partial! 'shared/utc_date_format', item: @item
