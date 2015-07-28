json.array! @items do |fc|
  json.cache! [controller_name, action_name, fc] do
    json.(fc, :id, :name, :description, :position)
    json.partial! 'shared/utc_date_format', item: fc
  end
end
