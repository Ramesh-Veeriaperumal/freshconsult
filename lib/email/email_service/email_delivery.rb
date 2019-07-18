module Email::EmailService::EmailDelivery

require 'net/http/persistent'
include ActionView::Helpers::NumberHelper
include Helpdesk::Email::OutgoingCategory
include ParserUtil
include EmailHelper
include EmailCustomLogger
include Email::EmailService::IpPoolHelper
 FD_EMAIL_SERVICE = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
 EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE["key"]
 EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE["host"]
 EMAIL_SERVICE_TIMEOUT = FD_EMAIL_SERVICE["timeout"]
 EMAIL_SERVICE_URL = FD_EMAIL_SERVICE["email_send_urlpath"]
 ACCOUNT_VALIDATE_URLPATH = FD_EMAIL_SERVICE["account_validate_urlpath"]
 class EmailDeliveryError < StandardError
 end

  def deliver_email(params, attachments = [], email_type = "")
    params = merge_email_content_to_params(params, attachments, email_type, params[:html], params[:text])
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
      Rails.logger.info "Email Service Response: #{response.body.inspect}"
      Rails.logger.info "Email sent from #{params[:from]} to #{params[:to]} #{(end_time - start_time).round(3)}ms"
  end

  def get_email_data(params)
    subject = params[:subject].present? ? params[:subject] : "(no subject)"
    from_email = (!(params[:from]).nil? && (params[:from]).kind_of?(Array)) ? construct_email_json(params[:from][0] ): construct_email_json(params[:from])
    to_email = construct_email_json_array params[:to]
    cc = params[:cc].present? ? (construct_email_json_array params[:cc] ): nil
    bcc = params[:bcc].present? ? (construct_email_json_array params[:bcc]) : nil
    reply_to = ((!(params["Reply-To"]).nil? && (params["Reply-To"]).kind_of?(Array)) ? construct_email_json(params["Reply-To"][0] ): construct_email_json(params["Reply-To"])) if params["Reply-To"].present?
    account_id = params["X-FD-Account-Id"].present? ? params["X-FD-Account-Id"] : -1
    type = (params["X-FD-Type"].present?) ? params["X-FD-Type"] : "empty"
    notification_type = is_num?(type) ? type : get_notification_type_id(type) 
    category_id = get_notification_category_id(params, notification_type) 
    if category_id.blank?
        mailgun_traffic = get_mailgun_percentage
        if mailgun_traffic > 0 && Random::DEFAULT.rand(100) < mailgun_traffic
          category_id = get_category_id(true)
        else
          category_id = get_category_id
        end
    end
    ip_pool = nil
    sender_config = get_sender_config(account_id, category_id, type)
     Rails.logger.info "Recieved Sender Config: #{sender_config.inspect}"
    unless sender_config.nil?
      category_id = sender_config["categoryId"]
      ip_pool = sender_config["ipPoolName"]
    end
    properties = construct_properties(params, category_id)
    header = construct_headers params
    result =  {"headers" => header,
                "to" => to_email,
                "cc" => (!cc.nil? ? (remove_duplicate_emails(to_email.to_a, cc.to_a)) : cc),
                "bcc" => (!bcc.nil? ? (remove_duplicate_emails(to_email.to_a, cc.to_a, bcc.to_a)) : bcc),
                "from" => from_email,
                "replyTo" => reply_to,
                "subject" => subject,
                "text" => params[:text],
                "html" => params[:html],
                "accountId" => "#{account_id}",
                "categoryId" => "#{category_id}",
                "properties"=> properties
              }
    result.merge!("attachments" => params[:attachments]) if params[:attachments].present?
    result.merge!("ipPool" => ip_pool) unless ip_pool.nil?
    Rails.logger.info "Sending email: Headers: #{result.except("text", "html", "attachments").inspect}"
    email_logger.debug(result.inspect)
    return result.to_json
  end

  def construct_headers full_headers
    headers = full_headers.except(:from, :to, :bcc, :cc, :subject, :text, :html, "X-FD-Account-Id", "X-FD-Type", "X-FD-Ticket-Id", "X-FD-Note-Id", "X-FD-Email-Category", "Reply-To", "Reply-to", :attachments)
    message_id =""
    if headers["Message-ID"]
      message_id = headers["Message-ID"]
      headers.delete("Message-ID")
    else
      message_id = "<#{Mail.random_tag}.#{::Socket.gethostname}@email.freshdesk.com>"
    end
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
  def get_notification_category_id(headers, notification_type)
    category_id = get_category_header(headers)
    return category_id if category_id.present?
    if custom_category_enabled_notifications.include?(notification_type.to_i)
      state = get_subscription
      key = (state == "active" || state == "premium") ? 'paid' : 'free'
      return Helpdesk::Email::OutgoingCategory::CATEGORY_BY_TYPE["#{key}_email_notification".to_sym]
    end
  end

  def remove_duplicate_emails( to, cc, bcc=[])
    res = []
    unique_emails = (to.map{|pair| pair["email"]} + (bcc.empty? ? [] : (cc.map{|pair| pair["email"]}))).uniq
    if bcc.empty?
      cc.map{|pair| res<<pair if !unique_emails.include?(pair["email"])}
    else
      bcc.map{|pair| res<<pair if !unique_emails.include?(pair["email"])}
    end
    return uniq_emails res
  end

  def uniq_emails email_arr
    res = []
    uniqemails= []
    email_arr.each do |curr_email|
      if !(uniqemails.include?(curr_email["email"]))
        res << curr_email
        uniqemails << curr_email["email"]
      end
    end
    return res
  end

private
  def merge_email_content_to_params(params, attachments, email_type, html = "", text = "")
        params[:to] = params[:to].split(/,|\;/) if params[:to].is_a? String
        if !(html.present? || text.present?)
          text = render_to_string(email_type + ".text.plain", {formats: :text})
          html = render_to_string(email_type + ".text.html", {formats: :html})
        end
        coder = HTMLEntities.new
        hmtl = coder.encode(html, :named)
        params.merge!(:text => text, :html => html)
        attachment_hash_array = get_attachment_hash_array attachments
        params.merge!(:attachments => attachment_hash_array) if attachment_hash_array.present?
        return params
  end
  def get_attachment_hash_array attachments
    res = []
    attachments.each do |att|
      attachment_hash = {
        "filename" => att.content_file_name,
        "content"=> ActiveSupport::Base64.encode64(Paperclip.io_adapters.for(att.content).read).gsub("\n", "")
      }
      res << attachment_hash
    end
    return res
  end

end