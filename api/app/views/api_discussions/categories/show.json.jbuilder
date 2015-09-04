json.cache! [controller_name, action_name, @item] do
  json.extract! @item, :id, :name, :description, :position
  json.partial! 'shared/utc_date_format', item: @item
end
