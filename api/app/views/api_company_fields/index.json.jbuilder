json.array! @items do |api_company_field|
  json.cache! [controller_name, action_name, api_company_field] do
    json.(api_company_field, :id, :name, :label, :field_type, :position, :required_for_agent)
    json.default api_company_field.default_field?
    json.choices companies_custom_dropdown_choices api_company_field.choices if api_company_field.field_type.to_s == 'custom_dropdown'
    json.partial! 'shared/utc_date_format', item: api_company_field
  end
end
