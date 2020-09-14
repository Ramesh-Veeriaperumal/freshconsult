module EmailHelper
	include ActionView::Helpers::NumberHelper


  class NokogiriTimeoutError < Exception
  end

  class HtmlSanitizerTimeoutError < Exception
  end

  MAX_TIMEOUT = 7 # Sendgrid's timeout is 25 seconds
  REQUEST_TIMEOUT = 25
  SENDGRID_RETRY_TIME = 4.hours
  FRESHDESK_DOMAIN = 'freshdesk.com'.freeze
  COLLAB_STR_ARRAY = ['Invited to Team Huddle - [#', 'Mentioned in Team Huddle - [#',
                  'mentioned in Team Huddle - [#', 'Reply in Team Huddle - [#',
                  'Team Huddle - New Messages in [#', 'Team Huddle - New Message in [#'].freeze
  MESSAGE_ID_REGEX = /<+([^>]+)/

  def verify_inline_attachments(item, content_id)
    content = "\"cid:#{content_id}\""
    if item.is_a? Helpdesk::Ticket
      item.description_html.include?(content)
    elsif item.is_a? Helpdesk::Note
      item.body_html.include?(content) || item.full_text_html.include?(content)
    end
  end

  def check_for_auto_responders(model, headers)
    model.skip_notification = true if auto_responder?(headers)
  end

  def check_support_emails_from(model, user, account)
    model.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(user.email) == 0}
  end

  def auto_responder?(headers)
    headers.present? && check_headers_for_responders(Hash[JSON.parse(headers)])
  end

  def check_headers_for_responders header_hash
    (header_hash["Auto-Submitted"] =~ /auto-(.)+/i || header_hash["Precedence"] =~ /(bulk|junk|auto_reply)/i).present?
  end
	
	def attachment_exceeded_message size
		I18n.t('attachment_limit_failed_message', :size => number_to_human_size(size)).html_safe
	end

  def virus_attachment_message size
    I18n.t('attachment_contain_virus', :size => size)
  end

  def invalid_ccs_message ccs
    I18n.t('cc_dropped_message', :emails => h(ccs.join(", ")))
  end

  def large_email(time=nil)
    @large_email ||= (Time.now.utc - (time || start_time)).to_i > REQUEST_TIMEOUT
  end

  def mark_email(key, from, to, subject, message_id)
    value = { "from" => from, "to" => to, "subject" => subject, "message_id" => message_id }
    set_others_redis_hash(key, value)
    set_others_redis_expiry(key, SENDGRID_RETRY_TIME)
  end

  def run_with_timeout error
    Timeout.timeout(MAX_TIMEOUT, error) do
      yield
    end
  rescue error => e
    subject = "ProcessEmail :: Timeout Error - #{error}"
    Rails.logger.debug "Error in run_with_timeout #{error} #{e.backtrace}"
    NewRelic::Agent.notice_error(e)
    DevNotification.publish(SNS["mailbox_notification_topic"], subject, e.backtrace.inspect)
    yield # Running the same code without timeout, as a temporary way. Need to handle it better
  end

  def cleanup_attachments model
    model.attachments.destroy_all if model.new_record?
  end

  def reply_to_private_note?(all_keys)
    all_keys.present? and all_keys.any? { |key| key.to_s.include? "private-notification.freshdesk.com" }
  end

  def reply_to_notification?(key)
    key.to_s.include? "notification.freshdesk.com"
  end

  def reply_to_forward(all_keys)
    all_keys.present? && all_keys.any? { |key| key.to_s.include?("forward.freshdesk.com") }
  end

  def customer_removed_in_reply?(ticket, in_reply_to, parse_to_emails, cc_emails, from_email)
    to_emails_arr = []
    to_emails_arr << from_email[:email]
    parse_to_emails.each do |to_email|
      to_emails_arr << (parse_email to_email)[:email]
    end
    (to_emails_arr << cc_emails).flatten!
    if((!reply_to_notification?(in_reply_to)) && !to_emails_arr.include?(ticket.requester.email))
      return true
    end
    return false
  end

  def email_processing_log(msg, envelope_to_address = nil)
    log_msg = msg
    if Account.current.present?
      log_msg += ", account_id: #{Account.current.id}"
    end
    if envelope_to_address.present?
      log_msg += ", envelope_to: #{envelope_to_address}"
    end
    Rails.logger.info("#{log_msg}")
  end 

  def make_header(ticket_id=nil, note_id=nil, account_id=nil,type)
    headers = {
        "X-FD-Account-Id" => account_id,
        "X-FD-Type" => type
      }
    headers.merge!({"X-FD-Ticket-Id" => ticket_id}) if ticket_id
    headers.merge!({"X-FD-Note-Id" => note_id}) if note_id
    headers
  end  

  def replace_invalid_characters(t_format)
    begin
      params[t_format] = params[t_format].encode(Encoding::UTF_8, :undef => :replace, 
                                                              :invalid => :replace, 
                                                              :replace => '')
    rescue Exception => e
      Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
      NewRelic::Agent.notice_error(e,{:description => "Charset Encoding issue while replacing invalid characters with ===============> #{charset_encoding}"})
    end
  end
  def configure_email_config email_config
    Thread.current[:email_config] = email_config
  end

  def remove_email_config
    Thread.current[:email_config] = nil
  end

  def email_from_another_portal?(account, fetched_account_id)
    return true if (fetched_account_id and account.id != fetched_account_id.to_i)
    return false
  end

  def notify_account_blocks(account, subject, description)
    if account.present?
      domain = account.full_domain
      description << "\n Account : #{freshops_account_url(account)}"
    else
      domain = "not known"
    end
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, nil, {
            :subject => subject,
            :recipients => ["fd-block-alerts@freshworks.com"],
            :additional_info => {:info => description}
          })
  end

  def update_freshops_activity(account, reason, action_name)
    url_params = { :app_name => 'helpkit',
    :activity => {
      :email => Helpdesk::EMAIL[:auto_block_user],
      :reason => reason,
      :action_name => action_name,
      :account_id => "#{account.id}",
      :account_name => "#{account.full_domain}" 
      }
    }
    Fdadmin::APICalls.make_api_request_to_global( :post, url_params, "/api/v1/activity/create_activity", "freshopsadmin.freshdesk.com")
  end

  def antispam_enabled? account
    account.proactive_spam_detection_enabled?
  end

  def collab_email_reply? email_subject
    COLLAB_STR_ARRAY.any? { |s| email_subject.include?(s) } ? true : false
  end

  def freshops_account_url(account)
      "freshopsadmin.freshdesk.com/accounts/#{account.id}"
  end

  # This method tells whether the request from email service is authenticated or not.
  def authenticated_email_service_request? key
    fd_email_service = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
    incoming_email_api_key1 = fd_email_service["incoming_email_api_key1"]
    incoming_email_api_key2 = fd_email_service["incoming_email_api_key2"]
    return (key == incoming_email_api_key1 or key == incoming_email_api_key2)
  end

  # For checking whether the notifications are routed via email services
  def via_email_service? account, email_config
    return !(email_config && email_config.smtp_mailbox) && ($redis_others.get("ROUTE_NOTIFICATIONS_VIA_EMAIL_SERVICE") == "1" || account.launched?(:send_emails_via_fd_email_service_feature))
  end

  def imap_application_id
    $fd_email_service_credentials ||= (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
    return $fd_email_service_credentials["imap_application_id"]
  end

  def block_outgoing_email(account_id)
    Rails.logger.info("disabling Outgoing email for #{account_id}")
    add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, account_id)
  end

  def block_spam_account params
    account_id = params[:account_id]
    begin
      Sharding.select_shard_of(account_id) do
        curr_account = Account.find_by_id(account_id).make_current
        if !ismember?(SPAM_EMAIL_ACCOUNTS, curr_account.id)
          if !(curr_account.subscription.active?)
            add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, curr_account.id)
          end
          notify_outgoing_block(curr_account, params[:description])
        end
        Account.reset_current_account
      end
    rescue => e
      Rails.logger.info "Error while blocking the outgoing emails of Spam account #{account_id}"
    end
  end

  def notify_outgoing_block(account, rules)
    subject = "Detected suspicious spam account :#{account.id}" #should be called only when account object is set
    additional_info = "Emails sent by the account has suspicious content . Contains content blacklisted by rule : #{rules} ."
    additional_info << "Outgoing emails blocked!!" if !(Account.current.subscription.active?)
    notify_account_blocks(account, subject, additional_info)
    update_freshops_activity(account, "Outgoing emails blocked due to blacklisted spam rules match", "block_outgoing_email") if !(Account.current.subscription.active?)
  end

  def custom_bot_attack_rules
    if ($custom_bot_attack_rules.blank? || $custom_bot_rules_checked_time.blank? || $custom_bot_rules_checked_time < 5.minutes.ago)
      custome_bot_rules_list = get_all_members_in_a_redis_set(CUSTOM_BOT_RULES)
      $custom_bot_attack_rules = (custome_bot_rules_list.present? ? 
                  custome_bot_rules_list : Helpdesk::Email::Constants::CUSTOM_BOT_RULES)
      $custom_bot_rules_checked_time = Time.now
    end
    return $custom_bot_attack_rules
  end

  def parse_internal_date(internal_date)
    Time.parse(internal_date).getutc.iso8601
  rescue StandardError => err
    ::Rails.logger.error("Exception parsing internal date :: #{err.message}")
  end

  def composed_email?
    Account.current.composed_email_check_enabled? && !(params[:in_reply_to].present?) && !(params[:headers] =~ /in-reply-to: #{MESSAGE_ID_REGEX}/i)
  end
end
