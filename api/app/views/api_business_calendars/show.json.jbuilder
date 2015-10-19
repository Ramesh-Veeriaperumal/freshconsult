json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :time_zone, :created_at, :updated_at
  json.partial! 'shared/boolean_format', boolean_fields: { is_default: @item.is_default }
end
