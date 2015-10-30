json.extract! @item, :id, :name, :description
json.partial! 'shared/utc_date_format', item: @item
