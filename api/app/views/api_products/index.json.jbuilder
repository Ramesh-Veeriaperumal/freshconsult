json.array! @items do |product|
  json.cache! CacheLib.key(product, params) do
    json.extract! product, :id, :name, :description
    json.partial! 'shared/utc_date_format', item: product
  end
end
