json.extract! @item, :id, :name, :description, :note, :domains, :custom_fields
json.partial! 'shared/utc_date_format', item: @item
