json.array! @api_email_configs do |email_config|
  json.cache! email_config do
    json.(email_config, :id, :name, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, :product_id)
    json.partial! 'shared/utc_date_format', item: email_config
  end
end
