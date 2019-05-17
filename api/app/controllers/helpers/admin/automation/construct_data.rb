module Admin::Automation::ConstructData
  include Admin::AutomationConstants
  include Va::Constants

  private

  def construct_marketplace_app(action)
    action_hash = action.to_hash.dup.symbolize_keys
    name = action_hash.delete(:field_name).to_sym
    action_hash[:name] = INTEGRATION_DB_NAME_MAPPING[name]
    action_hash[:value] = INTEGRATION_DB_NAME_VALUE[name]
    action_hash[:include_va_rule] = "true"
    action_hash
  end

  def construct_webhook(action)
    action = action.dup
    action_hash = default_webhook_data(action)
    action_hash[:content_type] = WEBHOOK_CONTENT_TYPES_ID[action[:content_type]].to_s if action[:content_type].present?
    action_hash[:content_layout] = action[:content_layout].to_s if action[:content_layout].present?
    action_hash[:params] = webhook_content(action) if action[:content].present?
    action[:custom_headers] = action[:custom_headers].to_hash if action[:custom_headers].present?
    construct_auth_header(action, action_hash)
    action_hash
  end

  def default_webhook_data(action)
    {
        request_type: WEBHOOK_REQUEST_TYPES_ID[action[:request_type]].to_s,
        url: action[:url],
        name: action[:field_name],
        new_webhook_api: true,
    }
  end

  def webhook_content(action)
    if action[:content_layout].to_s == '1' || action[:content_type] == 'JSON'
      action[:content].to_hash rescue action[:content]
    else
      action[:content].to_s
    end
  end

  def construct_auth_header(action, action_hash)
    if action[:auth_header].present?
      action_hash[:need_authentication] = "true"
      action_hash[:username] = action[:auth_header][:username] if action[:auth_header][:username].present?
      action_hash[:password] = action[:auth_header][:password].present? ? action[:auth_header][:password] : password_of_existing_webhook
      action_hash[:api_key] = action[:auth_header][:api_key] if action[:auth_header][:api_key].present?
    end
  end

  def password_of_existing_webhook
    webhook_rule = retrieve_existing_property(@item.action_data, :field_name, :trigger_webhook)
    webhook_rule.try(:[], :password)
  end

  def retrieve_existing_property(data, key, name)
    return nil if data.blank? || !data.is_a?(Array)
    data.find { |each_data| (each_data[key].to_sym rescue each_data[key]) == name }
  end

end