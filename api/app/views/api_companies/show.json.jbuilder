json.cache! CacheLib.compound_key(@item, @item.custom_field, params) do
  json.extract! @item, :id, :name, :description, :domains, :note, :created_at, :updated_at
  json.domains CompanyDecorator.csv_to_array(@item.domains)

  json.custom_fields @item.custom_field
end
