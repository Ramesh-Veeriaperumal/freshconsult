json.cache! @item do
  json.(@item, :id, :name, :product_id, :to_email, :reply_email, :group_id, :product_id)
  json.partial! 'shared/boolean_format', boolean_fields: { primary_role: @item.primary_role, active: @item.active }
  json.partial! 'shared/utc_date_format', item: @item
end
