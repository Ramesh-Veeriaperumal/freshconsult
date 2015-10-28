json.array! @items do |api_company|
  json.cache! CacheLib.compound_key(api_company, params) do
    json.extract! api_company, :id, :name, :description, :note, :created_at, :updated_at
    json.domains CompanyDecorator.csv_to_array(api_company.domains)
  end
  # Not caching as decimal values are read as big decimal object
  # which in turn causes cache to be regenerated for every request as objects will be different.
  json.custom_fields api_company.custom_field
end
