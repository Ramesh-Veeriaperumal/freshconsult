json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :domains, :note
  json.domains CompanyDecorator.csv_to_array(@item.domains)
  json.partial! 'shared/utc_date_format', item: @item
end

json.custom_fields @item.custom_field
