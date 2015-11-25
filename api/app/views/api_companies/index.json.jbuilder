json.array! @items do |api_company|
  json.cache! CacheLib.key(api_company, params) do
    json.extract! api_company, :id, :name, :description, :note
    json.domains CompanyDecorator.csv_to_array(api_company.domains)
    json.partial! 'shared/utc_date_format', item: api_company
  end
  # Not caching as decimal values are read as big decimal object
  # which in turn causes cache to be regenerated for every request as objects will be different.
  json.custom_fields CustomFieldDecorator.remove_prepended_text_from_custom_fields(api_company.custom_field)
end
