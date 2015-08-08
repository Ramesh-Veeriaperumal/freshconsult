json.(@item, :id, :name, :description, :active, :conditions, :is_default, :position)
json.partial! 'shared/utc_date_format', item: @item
