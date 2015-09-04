json.cache! [controller_name, action_name, @item] do
  json.extract! @item, :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, :product_id
  json.partial! 'shared/utc_date_format', item: @item
end
