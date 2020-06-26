module Email::EmailService::EmailCampaignDelivery
  require 'net/http/persistent'
  include ::Proactive::EmailUnsubscribeUtil

  FD_EMAIL_SERVICE = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
  EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE['key']
  EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE['host']
  EMAIL_SERVICE_TIMEOUT = FD_EMAIL_SERVICE['timeout']
  EMAIL_SERVICE_URL = FD_EMAIL_SERVICE['email_campaign_urlpath']
  ACCOUNT_VALIDATE_URLPATH = FD_EMAIL_SERVICE['account_validate_urlpath']
  USER = 'user'.freeze
  COMPANY = 'company'.freeze
  PLACEHOLDER_KEY_MAP = {
    "user" => "contact",
    "company" => "company"
  }.freeze

  class EmailDeliveryError < StandardError
  end

  def deliver_email_campaign(params)
    Rails.logger.info "Email Sending initiated for params #{params}}"
    start_time = Time.now
    response = post_email_campaign_to_service(connection_builder, params)
    if response.status != 200
      Rails.logger.info "Email sending failed due to : #{response.body['Message']}"
      raise EmailDeliveryError, response.body['Message']
    end
    end_time = Time.now
    Rails.logger.info "Successfully sent bulk emails, Email Service Response: #{response.body.inspect}"
    Rails.logger.info "Bulk email sent from account_id #{params[:account_id]} for #{params[:user_ids]} in about #{(end_time - start_time).round(3)}seconds"
  end

  def connection_builder
    Faraday.new(EMAIL_SERVICE_HOST) do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter  :net_http_persistent
    end
  end

  def post_email_campaign_to_service(con, params)
    con.post do |req|
      req.url '/' + EMAIL_SERVICE_URL
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = EMAIL_SERVICE_AUTHORISATION_KEY
      req.options.timeout = EMAIL_SERVICE_TIMEOUT
      req.body = email_data params
    end
  end

  def email_data(params)
    params[:subject] = params[:subject].gsub('{{', '${').gsub('}}', '}')
    params[:description] = params[:description].gsub('{{', '${').gsub('}}', '}')
    {
      'subject' => params[:subject].presence || "Notification from #{Account.current.helpdesk_name}",
      'html' => params[:description].present? ? params[:description].concat("<p>Click to <a href = ${contact.unsubscribe_link}>unsubscribe</a> from these emails</p>") : '',
      'tags' => tags(params),
      'accountId' => params[:account_id].to_s,
      'headers' => {},
      'from' => from_email(params[:email_config_id]),
      'cc' => cc_emails(params[:cc_emails])
    }.to_json
  end

  def tags(params)
    user_ids = params[:user_ids]
    Account.current.users.with_user_ids(user_ids).preload(:flexifield, :default_user_company, :companies).each_with_object([]) do |contact, tags|
      unless contact.simple_outreach_unsubscribe?
        placeholder_tags = html_tags(contact, params)
        tags << {
          'email' => contact.email,
          'name' => contact.name,
          'html_tags' => placeholder_tags,
          'subject_tags' => placeholder_tags
        }
      end
    end
  end

  def html_tags(contact, params)
    placeholder_values = {}
    placeholder_values.merge!(placeholder_substitues(contact))
    if contact.company.present?
      placeholder_values.merge!(placeholder_substitues(contact.company))
    else
      placeholder_values.merge!(handle_nil_placeholders(params[:subject].scan(/\${company.*?}/)))
      placeholder_values.merge!(handle_nil_placeholders(params[:description].scan(/\${company.*?}/)))
    end
    placeholder_values
  end

  def placeholder_substitues(customer)
    customer_klass_name = customer.class.name.downcase
    customer_attr_hash = customer.as_json[customer_klass_name]
    placeholer_hash = customer_attr_hash.keys.inject({}) do |a, key|
      if key == :custom_field
        custom_field_hash = customer_attr_hash[:custom_field]
        custom_field_hash.keys.each do |custom_field_key|
          a.merge!("${#{PLACEHOLDER_KEY_MAP[customer_klass_name]}.custom_field.#{custom_field_key.to_s}}": custom_field_hash[custom_field_key].to_s)
        end
      else
        a.merge!("${#{PLACEHOLDER_KEY_MAP[customer_klass_name]}.#{key.to_s}}": customer_attr_hash[key].to_s)
      end
      a
    end.stringify_keys
    placeholer_hash.merge!("${contact.unsubscribe_link}" => generate_unsubscribe_link(customer)) if customer.is_a?(User)
    placeholer_hash
  end

  def from_email(email_config_id)
    email_config = Account.current.all_email_configs.find_by_id(email_config_id)
    email_config.try(:friendly_email_hash)
  end

  def cc_emails(ccs)
    ccs.present? ? (ccs.inject([]) { |acc, email| acc << { 'email' => email } }) : []
  end

  def handle_nil_placeholders(place_holders)
    empty_placeholders = {}
    place_holders.each do |value|
      empty_placeholders.merge!(value => '')
    end
    empty_placeholders
  end
end
