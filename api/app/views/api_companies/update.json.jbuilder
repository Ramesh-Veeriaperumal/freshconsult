json.extract! @item, :id, :name, :description, :note
json.domains CompanyDecorator.csv_to_array(@item.domains)
json.custom_fields CustomFieldDecorator.utc_format(@item.custom_field)
json.partial! 'shared/utc_date_format', item: @item
