json.(@item, :id, :name, :description, :note)
json.domains CompanyDecorator.csv_to_array(@item.domains)
json.custom_fields @item.custom_field
json.partial! 'shared/utc_date_format', item: @item
