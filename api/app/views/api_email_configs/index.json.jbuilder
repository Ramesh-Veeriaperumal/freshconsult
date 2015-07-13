json.array! @api_email_configs do |email_config|
  json.cache! email_config do
    json.(email_config, :id, :name, :product_id, :to_email, :reply_email, :group_id, :product_id)
    json.partial! 'shared/boolean_format', boolean_fields: { primary_role: email_config.primary_role, active: email_config.active }
    json.partial! 'shared/utc_date_format', item: email_config
  end
end
