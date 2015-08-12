json.(@item, :id, :name, :description, :active, :is_default, :position)
json.applicable_to api_pluralize_keys(@item.conditions)
json.partial! 'shared/utc_date_format', item: @item
