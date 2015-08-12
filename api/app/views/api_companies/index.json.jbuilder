json.array! @items do |api_company|
  json.cache! [controller_name, action_name, api_company] do
    json.(api_company, :id, :name, :description, :note)
    json.domains api_item_array(api_company.domains)
    json.partial! 'shared/utc_date_format', item: api_company
  end
  json.custom_fields api_company.custom_field
end
