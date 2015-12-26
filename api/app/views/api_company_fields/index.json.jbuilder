json.array! @items do |api_company_field|
  json.cache! CacheLib.compound_key(api_company_field, api_company_field.choices, params) do
    json.extract! api_company_field, :id, :name, :label, :position, :required_for_agent
    json.type api_company_field.field_type
    json.default api_company_field.default_field?
    json.choices api_company_field.companies_custom_dropdown_choices if api_company_field.field_type.to_s == 'custom_dropdown'
    json.partial! 'shared/utc_date_format', item: api_company_field
  end
end
