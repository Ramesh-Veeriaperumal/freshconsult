json.array! @items do |api_company_field|
  json.cache! CacheLib.key(api_company_field, params) do
    json.extract! api_company_field, :id, :name, :label, :field_type, :position, :required_for_agent
    json.default api_company_field.default_field?
    json.choices CompanyFieldDecorator.companies_custom_dropdown_choices(api_company_field) if api_company_field.field_type.to_s == 'custom_dropdown'
    json.partial! 'shared/utc_date_format', item: api_company_field
  end
end
