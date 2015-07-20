json.array! @items do |product|
  json.cache! [controller_name, action_name, product] do
    json.(product, :id, :name, :description)
    json.partial! 'shared/utc_date_format', item: product
  end
end
