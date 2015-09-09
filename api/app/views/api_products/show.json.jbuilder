  json.cache! CacheLib.key(@api_product, params) do
    json.extract! @item, :id, :name, :description
    json.partial! 'shared/utc_date_format', item: @item
  end
