module EmailDelivery

require 'net/http/persistent'
include ActionView::Helpers::NumberHelper
include Helpdesk::Email::OutgoingCategory
include ParserUtil

 FD_EMAIL_SERVICE = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
 EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE["key"]
 EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE["host"]
 EMAIL_SERVICE_TIMEOUT = FD_EMAIL_SERVICE["timeout"]
 EMAIL_SERVICE_URL = FD_EMAIL_SERVICE["email_send_urlpath"]
 ACCOUNT_VALIDATE_URLPATH = FD_EMAIL_SERVICE["account_validate_urlpath"]
 class EmailDeliveryError < StandardError
 end

  def deliver_email(params, attachments)

    Rails.logger.info "Email Sending initiated for #{params["Message-ID"]}"
    start_time = Time.now
    con = Faraday.new(EMAIL_SERVICE_HOST) do |faraday|
            faraday.response :json, :content_type => /\bjson$/ 
            faraday.adapter  :net_http_persistent
          end
      response = con.post do |req|
        req.url "/"+ EMAIL_SERVICE_URL
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = EMAIL_SERVICE_AUTHORISATION_KEY
        req.options.timeout = EMAIL_SERVICE_TIMEOUT
        req.body = get_email_data params
      end

      if response.status != 200
        Rails.logger.info "Email sending failed due to : #{response.body["Message"]}"
        raise EmailDeliveryError, response.body["Message"]
      end
      end_time = Time.now
      Rails.logger.info "Email sent from #{params[:from]} to #{params[:to]} (%1.fms)" %(end_time - start_time)
  end

  def get_email_data(params)
    subject = !params[:subject].nil? ? params[:subject] : "No Subject"
    from_email = (!(params[:from]).nil? && (params[:from]).kind_of?(Array)) ? construct_email_json(params[:from][0] ): construct_email_json(params[:from])
    to_email = construct_email_json_array params[:to]
    cc = params[:cc].present? ? (construct_email_json_array params[:cc] ): nil
    bcc = params[:bcc].present? ? (construct_email_json_array params[:bcc]) : nil
    reply_to = construct_email_json params["Reply-To"]
    account_id = params["X-FD-Account-Id"].present? ? params["X-FD-Account-Id"] : -1
    subject = params[:subject]
    type = (params["X-FD-Type"].present?) ? params["X-FD-Type"] : "empty"
    category_id = get_notification_category_id(params, type) || check_spam_category(params, type)
    if category_id.blank?
        mailgun_traffic = get_mailgun_percentage
        if mailgun_traffic > 0 && Random::DEFAULT.rand(100) < mailgun_traffic
          category_id = get_category_id(true)
        else
          category_id = get_category_id
        end
    end
    properties = construct_properties(params, category_id)
    Rails.logger.info "Sending email: properties: #{properties.inspect}"
    header = construct_headers params
    Rails.logger.info "Sending email: Headers: #{header.inspect}"

    result =  {"headers" => header,
                "to" => to_email,
                "cc" => (!cc.nil? ? (cc.to_a - to_email.to_a) : cc),
                "bcc" => (!bcc.nil? ? (bcc.to_a - cc.to_a - to_email.to_a) : bcc),
                "from" => from_email,
                "replyTo" => reply_to,
                "subject" => subject,
                "text" => params[:text],
                "html" => params[:html],
                "accountId" => "#{account_id}",
                "categoryId" => "#{category_id}",
                "properties"=> properties
              }
    return result.to_json
  end

  def construct_headers full_headers
    headers = full_headers.except(:from, :to, :bcc, :cc, :subject, :text, :html, "X-FD-Account-Id", "X-FD-Type", "X-FD-Ticket-Id", "X-FD-Note-Id", "X-FD-Email-Category", "Reply-To")
    message_id = headers["Message-ID"]
    headers.delete("Message-ID")
    headers.merge!("messageId" => message_id)
    headers
  end
  def construct_properties(headers, category_id = -1)
      mail_type = (headers["X-FD-Type"].present?) ? headers["X-FD-Type"] : "empty"
      account_id = headers["X-FD-Account-Id"].present? ? headers["X-FD-Account-Id"] : -1
      ticket_id = headers["X-FD-Ticket-Id"].present? ? headers["X-FD-Ticket-Id"] : -1
      note_id = headers["X-FD-Note-Id"]
      note_id_str = !note_id.nil? ? "\"note_id\": \"#{note_id}\"," : ""
      from_email = (!(headers[:from]).nil? && (headers[:from]).kind_of?(Array)) ? parse_email(headers[:from][0]) : parse_email(headers[:from])
      from_email_text = from_email.nil? ? "" : from_email[:email]
      shard_info = get_shard account_id
      pod_info = get_pod
      
      result_hash = {
                      "account_id" => "#{account_id}",
                      "ticket_id" => "#{ticket_id}", 
                      "note_id" => "#{note_id}", 
                      "email_type" => "#{mail_type}",
                      "from_email" => from_email_text,
                      "category_id" => "#{category_id}", 
                      "pod_info" => "#{pod_info}",
                      "shard_info" => "#{shard_info}"
                    }
    return result_hash
  end

  def check_spam_category(mail, type)
    category = nil
    notification_type = is_num?(type) ? type : get_notification_type_id(type) 
    if account_created_recently? && spam_filtered_notifications.include?(notification_type)
      response = FdSpamDetectionService::Service.new(Helpdesk::EMAIL[:outgoing_spam_account], mail.to_s).check_spam
      category = Helpdesk::Email::OutgoingCategory::CATEGORY_BY_TYPE[:spam] if response.spam?
      Rails.logger.info "Spam check response for outgoing email: #{response.spam?}"
    end
    return category
  end

  def is_num?(str)
    !!Integer(str)
    rescue ArgumentError, TypeError
     false
  end

  def get_notification_type_id(text)
	EmailNotificationConstants::NOTIFICATION_TYPES.key(text)
  end
 
  def get_notification_type_text(type)
    type = type.to_i
    EmailNotificationConstants::NOTIFICATION_TYPES[type]
  end
  
  def get_category_header(headers)
    headers["X-FD-Email-Category"].to_s.to_i if headers["X-FD-Email-Category"].present?
  end

  def construct_email_json_array email_array
    email_json_array = []
    if(!email_array.nil? && email_array.kind_of?(Array))
      email_array.each do |email|
        email_json_array.push(construct_email_json email)
      end
    end
    email_json_array
  end

  def construct_email_json email
    parsed_email = parse_email email
    email_hash = {
      "email" => parsed_email[:email],
      "name" => parsed_email[:name]
    }
    email_hash
  end

  def get_shard account_id
    shard = ShardMapping.fetch_by_account_id(account_id)
    shard.nil? ? "unknown" : shard.shard_name
  end

  def get_pod
    PodConfig['CURRENT_POD']
  end
  def get_notification_category_id(headers, type)
    category_id = get_category_header(headers)
    return category_id if category_id.present?
    notification_type = is_num?(type) ? type : get_notification_type_id(type)
    if custom_category_enabled_notifications.include?(notification_type.to_i)
      state = get_subscription
      key = (state == "active" || state == "premium") ? 'paid' : 'free'
      return Helpdesk::Email::OutgoingCategory::CATEGORY_BY_TYPE["#{key}_email_notification".to_sym]
    end
  end

end