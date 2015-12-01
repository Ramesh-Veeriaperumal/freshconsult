json.extract! @item, :id, :name, :description, :note
json.domains CompanyDecorator.csv_to_array(@item.domains)
json.custom_fields CompanyDecorator.remove_prepended_text_from_company_fields(@item.custom_field, @custom_fields_api_name_mapping)
json.partial! 'shared/utc_date_format', item: @item
