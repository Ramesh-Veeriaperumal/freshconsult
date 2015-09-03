json.(@item, :id, :name, :description, :note)
json.domains @item.csv_to_array
json.custom_fields @item.custom_field
json.partial! 'shared/utc_date_format', item: @item
