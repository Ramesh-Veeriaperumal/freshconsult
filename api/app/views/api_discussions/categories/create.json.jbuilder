json.(@category, :id, :name, :description, :position)
json.partial! 'shared/utc_date_format', item: @category