json.array! @items do |api_company|
  json.cache! api_company do
    json.(api_company, :id, :name, :description, :domains, :note)
    json.custom_fields api_company.custom_field
    json.partial! 'shared/utc_date_format', item: api_company
  end
end
