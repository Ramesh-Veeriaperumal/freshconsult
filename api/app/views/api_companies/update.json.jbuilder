json.extract! @item, :id, :name, :description, :note, :created_at, :updated_at
json.domains CompanyDecorator.csv_to_array(@item.domains)
json.custom_fields @item.custom_field
