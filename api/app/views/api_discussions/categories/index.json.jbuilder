json.array! @categories do |fc|
  json.cache! fc do
    json.(fc, :id, :name, :description, :position)
    json.partial! 'shared/utc_date_format', item: fc
  end
end
