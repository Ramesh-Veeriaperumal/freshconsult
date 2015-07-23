json.array! @items do |api_company_field|
  json.cache! api_company_field do
    json.(api_company_field, :id, :name, :label, :field_type, :position, :required_for_agent)
    json.default api_company_field.default_field?
    json.partial! 'shared/utc_date_format', item: api_company_field
  end
end
