json.(@item, :id, :name, :description, :note)
json.domains api_item_array(@item.domains)
json.custom_fields @item.custom_field
json.partial! 'shared/utc_date_format', item: @item
