  json.cache! [controller_name, action_name, @api_product] do
    json.(@item, :id, :name, :description)
    json.partial! 'shared/utc_date_format', item: @item
  end
