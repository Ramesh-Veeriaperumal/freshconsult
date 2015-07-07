json.cache! @api_email_config do
  json.(@api_email_config, :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, :product_id)
  json.partial! 'shared/utc_date_format', item: @api_email_config
end
