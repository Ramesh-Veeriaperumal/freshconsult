module Admin::Automation::ActionHelper
  include Admin::AutomationConstants
  include Admin::AutomationValidationHelper
  include Admin::Automation::WebhookValidations

  def action_validation(expected, actual)
    case expected[:field_type]
      when :dropdown, :text
        validate_action_value(expected, actual)
      when :webhook
        validate_webhook(expected, actual)
      when :email
        validate_send_email(expected, actual)
      when :add_note_type
        validate_notify_emails(expected, actual)
      when :forward_note
        validate_forward_note(expected, actual)
      when :nested_field
        validate_nested_field(expected, actual, :action, :nested_fields)
      else #label
        validate_label_field_type(expected, actual)
    end
    validate_resource_type(expected, actual) if actual.key?(:resource_type)
  end

  def validate_resource_type(expected, actual)
    unexpected_parameter('resource_type') if supervisor_rule?
    allowed_types = dispatcher_rule? ? DISPATCHER_ACTION_TICKET_ASSOCIATION_TYPES : OBSERVER_ACTION_TICKET_ASSOCIATION_TYPES
    not_included_error(:"#{expected[:name]}[:resource_type]",
                       allowed_types) if !allowed_types.include?(actual[:resource_type])
  end

  def validate_action_value(expected, actual)
    if actual.key?(:value)
      is_expected_data_type = valid_action_data_type?(expected, actual[:value])
      expected_type = expected[:multiple] ? 'list' : ERROR_MESSAGE_DATA_TYPE_MAP[expected[:data_type]]
      invalid_data_type(expected[:name], expected_type, 'invalid') unless is_expected_data_type
    else
      missing_field_error(expected[:name], 'value')
    end
  end

  def valid_action_data_type?(expected, value)
    data_type_class = expected[:data_type].to_s.constantize
    is_expected_data_type = value.is_a?(data_type_class)
    expected[:allow_any_type] || is_expected_data_type || none_value?(value,
                                         expected[:field_type] == :nested_field || ACTION_NONE_FIELDS.include?(expected[:name]))
  end

  def validate_webhook(expected, actual)
    if (actual.keys - WEBHOOK_PERMITTED_PARAMS).present?
      invalid_value_list(expected[:name], WEBHOOK_PERMITTED_PARAMS, message = :invalid_attribute_for_key)
    end
    missing_field_error(expected[:name], :url) unless actual.key?(:url)
    validate_auth_header(expected[:name], actual[:auth_header]) if actual.key?(:auth_header)

    headers = actual[:custom_headers]
    if Account.current.webhook_blacklist_ip_enabled? && !valid_webhook_url?(actual[:url])
      invalid_url(:trigger_webhook, actual[:url]) 
    end
    
    invalid_data_type(:"#{expected[:name]}[:custom_headers]", :JSON, :invalid) if actual.key?(:custom_headers) && !headers.is_a?(Hash)
    validate_based_on_http_method(actual[:request_type].to_sym, expected, actual)

  end

  def validate_based_on_http_method(method_name, expected, actual)
    case method_name
      when :GET, :DELETE
        unexpected_parameter(:"#{expected[:name]}[:content_layout]") if actual.key? :content_layout
        unexpected_parameter(:"#{expected[:name]}[:content_type]") if actual.key? :content_type
        unexpected_parameter(:"#{expected[:name]}[:content]") if actual.key? :content
      when :PATCH, :POST, :PUT
        missing_field_error(expected[:name], :content_type) unless actual.key? :content_type
        missing_field_error(expected[:name], :content_layout) unless actual.key? :content_layout
        missing_field_error(expected[:name], :content) unless actual.key? :content
        if actual.key?(:content) && actual.key?(:content_layout) && actual[:content_type].is_a?(String)
          check_content_type(actual[:content_type], actual[:content_layout], actual[:content], expected[:name])
        end
      else
        actual.key?(:request_type) ? unexpected_parameter(:"#{expected[:name]}[:request_type]") :
            missing_field_error(expected[:name], :request_type)
    end
  end

  def validate_auth_header(field_name, header)
    not_included_error(:"#{field_name}[:auth_header]", WEBHOOK_AUTH_HEADER_KEY) if header.blank?
    if header.is_a?(Hash)
      invalid_auth_keys = (header.keys - (WEBHOOK_AUTH_HEADER_KEY & header.keys))
      username, password, api_key = header[:username], header[:password], header[:api_key]
      if invalid_auth_keys.present?
        unexpected_value_for_attribute(:"#{field_name}[:auth_header]", invalid_auth_keys.join(','))
      elsif username.present? && api_key.present?
        unexpected_parameter(:"#{field_name}[:auth_header]", :webhook_auth_header_error)
      else
        invalid_data_type(:"#{field_name}[:auth_header][:api_key]",
                          :String, :invalid) if api_key.present? && !api_key.is_a?(String)
      end
    else
      invalid_data_type(:"#{field_name}[:auth_header]", :JSON, :invalid)
    end
  end

  def check_content_type(type, layout, content, field_name)
    case type.to_sym
      when :JSON
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 1 || layout != 2
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) if !content.is_a?(Hash) && layout == 1
      when :XML
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 2
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) unless content.is_a?(String)
      when :'X-FORM-URLENCODED'
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 1
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) unless content.is_a?(Hash)
      else
        unexpected_parameter(:"#{field_name}[:content_type]")
    end
  end

  def validate_notify_emails(expected,actual)
    missing_field_error(expected[:name], :note_body) unless actual.key? :note_body
    invalid_data_type(:"#{expected[:name]}[:note_body]",:String,:invalid) if actual[:note_body].present? && !actual[:note_body].is_a?(String)
    invalid_data_type(:"#{expected[:name]}[:notify_agents]", :array, :invalid) if actual[:notify_agents].present? && !actual[:notify_agents].is_a?(Array)
    if (actual.key? (:notify_agents)) && (actual[:notify_agents].is_a?(Array))
      actual[:notify_agents].each_with_index do |agent_id,index|
        invalid_data_type(:"#{expected[:name]}[:notify_agents][index_#{index}]", :number, :invalid) unless agent_id.is_a?(Integer)
      end
    end
  end

  def validate_send_email(expected, actual)
    unexpected_parameter(:"#{expected[:name]}[:email_subject]") if actual[:email_subject].present? && !actual[:email_subject].is_a?(String)
    unexpected_parameter(:"#{expected[:name]}[:email_body]") if actual[:email_body].present? && !actual[:email_body].is_a?(String)
    missing_field_error(expected[:name], :email_subject) unless actual.key? :email_subject
    missing_field_error(expected[:name], :email_body) unless actual.key? :email_body

    if expected[:name] == :send_email_to_group || expected[:name] == :send_email_to_agent
      missing_field_error(actual[:name], :email_to) unless actual.key? :email_to
      invalid_data_type(:"#{expected[:name]}[:email_to]", :number, :invalid) unless actual[:email_to].is_a?(Integer)
    else
      unexpected_parameter(:"#{expected[:name]}[:email_to]") if actual.key? :email_to
    end
  end

  def validate_forward_note(expected, actual)
    missing_field_error(actual[:name], :fwd_to) unless actual.key? :fwd_to
    [:fwd_to, :fwd_cc, :fwd_bcc].each do |field_name|
      next unless actual[field_name].present?
      actual[field_name].is_a?(Array) ? validate_email(field_name, actual[field_name]) : invalid_data_type(:"#{expected[:name]}[#{field_name}", :array, :invalid)
    end
    invalid_data_type(:"#{expected[:name]}[:fwd_note_body]", :string, :invalid) if actual[:fwd_note_body].present? && !actual[:fwd_note_body].is_a?(String)
    invalid_data_type(:"#{expected[:name]}[:show_quoted_text]", :boolean, :invalid) if actual[:show_quoted_text].present? && !actual[:show_quoted_text].in?([true, false])
    missing_field_error(actual[:name], :'fwd_note_body/show_quoted_text') if actual[:fwd_note_body].blank? && !actual[:show_quoted_text]
  end
end
