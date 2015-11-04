json.cache! CacheLib.compound_key(@item, @item.custom_field, params) do
  json.extract! @item, :id, :name, :description, :domains, :note
  json.domains CompanyDecorator.csv_to_array(@item.domains)
  json.partial! 'shared/utc_date_format', item: @item

  json.custom_fields CustomFieldDecorator.utc_format(@item.custom_field)
end
