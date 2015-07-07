  json.cache! @api_product do
    json.(@api_product, :id, :name, :description)
    json.partial! 'shared/utc_date_format', item: @api_product
  end
