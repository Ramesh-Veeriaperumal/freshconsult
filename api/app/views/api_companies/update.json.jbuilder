json.(@item, :id, :name, :description, :domains, :note)
json.custom_fields @item.custom_field
json.partial! 'shared/utc_date_format', item: @item
