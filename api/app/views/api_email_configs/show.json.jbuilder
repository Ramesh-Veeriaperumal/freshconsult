json.cache! @api_email_config do
  json.(@api_email_config, :id, :name, :product_id, :to_email, :reply_email, :group_id, :product_id)
  json.partial! 'shared/boolean_format', boolean_fields: { primary_role: @api_email_config.primary_role, active: @api_email_config.active }
  json.partial! 'shared/utc_date_format', item: @api_email_config
end
