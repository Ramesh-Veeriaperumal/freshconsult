json.extract! @item, :id, :name, :description, :note
json.domains CompanyDecorator.csv_to_array(@item.domains)
json.custom_fields CustomFieldDecorator.remove_prepended_text_from_custom_fields(@item.custom_field, 3, -1)
json.partial! 'shared/utc_date_format', item: @item
