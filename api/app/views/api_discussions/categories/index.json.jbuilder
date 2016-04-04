json.array! @items do |fc|
  json.cache! CacheLib.key(fc, params) do
    json.extract! fc, :id, :name, :description
    json.partial! 'shared/utc_date_format', item: fc
  end
end
