json.array! @api_products do |product|
  json.cache! product do
    json.(product, :id, :name, :description)
    json.partial! 'shared/utc_date_format', item: product
  end
end
