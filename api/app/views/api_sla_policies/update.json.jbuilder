json.(@item, :id, :name, :description, :active, :is_default, :position)
json.applicable_to @item.pluralize_conditions
json.partial! 'shared/utc_date_format', item: @item
