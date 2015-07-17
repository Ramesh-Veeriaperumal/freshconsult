json.array! @items do |api_company_field|
  json.cache! api_company_field do
    json.(api_company_field, :id, :account_id, :company_form_id, :name, :column_name, :label, :field_type, :position, :deleted, :required_for_agent, :field_options)
    json.partial! 'shared/utc_date_format', item: api_company_field
  end
end
