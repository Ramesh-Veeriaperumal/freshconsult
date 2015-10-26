json.array! @items do |api_company|
  json.cache! CacheLib.compound_key(api_company, api_company.custom_field, params) do
    json.extract! api_company, :id, :name, :description, :note, :created_at, :updated_at
    json.domains CompanyDecorator.csv_to_array(api_company.domains)
    json.custom_fields api_company.custom_field
  end
end
