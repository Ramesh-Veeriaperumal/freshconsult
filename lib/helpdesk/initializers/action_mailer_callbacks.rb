require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks

  def self.included(base)
    base.extend ClassMethods
    base.extend Helpdesk::Email::OutgoingCategory
  end

  module ClassMethods
  include ParserUtil
  include EmailHelper
  include Email::EmailService::IpPoolHelper
  include Email::Mailbox::Oauth2Helper

  def send_email(notification_type, recipient, *args)
    language = mailer_language(recipient)
    send_email_with_lang(notification_type, language, *args)
  end

  def send_email_with_lang(notification_type, language, *args)
    I18n.with_locale(language) { safe_send(notification_type, *args) }
  rescue => e
    Rails.logger.error "Error while sending mail: #{notification_type}\n#{e.message}\n#{e.backtrace.to_a.join("\n")}"
  end

  def send_email_to_group(notification_type, all_emails, *args)
    emails_by_locale(all_emails).each do |language, group_emails|
      next if group_emails.empty?
      email_hash = { group: group_emails, other: all_emails - group_emails }
      send_email_with_lang(notification_type, language, email_hash, *args)
    end
  end

  def emails_by_locale(emails)
    email_groups_by_locale = Hash.new { |h, k| h[k] = [] }
    users = Account.current.users.where(email: emails)
    user_emails = users.map(&:email)
    users.each { |user| email_groups_by_locale[user_locale(user)].push(user.email) }
    default_locale = user_locale(nil)
    email_groups_by_locale[default_locale].push(*(emails - user_emails)) # send email in account's language
    email_groups_by_locale
  end

  def mailer_language(param)
    if param.is_a?(User) || param.nil?
      return user_locale(param)
    end
    user = Account.current.users.find_by_email(param) if valid_email?(param)
    user_locale(user)
  end

  def user_locale(user)
    (user && user.language) ? user.language : Account.current.default_account_locale
  end

    def set_smtp_settings(mail)
      account_id_field = mail.header["X-FD-Account-Id"]
      ticket_id_field = mail.header["X-FD-Ticket-Id"]
      mail_type_field = mail.header["X-FD-Type"]
      note_id_field = mail.header["X-FD-Note-Id"]
      account_id = account_id_field.value if account_id_field.present?
      ticket_id = ticket_id_field.value if ticket_id_field.present?
      note_id = note_id_field.value if note_id_field.present?
      mail_type = (mail_type_field.present? && mail_type_field.value.present?) ? mail_type_field.value : "empty"
      account_id = account_id.present? ? account_id : -1
      ticket_id = ticket_id.present? ? ticket_id : -1
      note_id = note_id_field.present? ? note_id : -1
      mail.header["X-FD-Account-Id"] = nil if account_id_field.present?
      mail.header["X-FD-Ticket-Id"] = nil if ticket_id_field.present?
      mail.header["X-FD-Type"] = nil if (mail_type_field.present? && mail_type_field.value.present?)
      mail.header["X-FD-Note-Id"] = nil if note_id_field.present?
      mail.header["X-ACCOUNT-ID"] = account_id
      if (!mail.header[:from].nil? && !mail.header[:from].value.nil?)
        from_email = mail.header[:from].value
        from_email = from_email.kind_of?(Array) ? from_email.first : from_email
        from_email = parse_email(from_email)[:email]
      else
        from_email = ""
      end
      category_id = nil
      email_config = Thread.current[:email_config]
      if (email_config && email_config.smtp_mailbox)
        smtp_mailbox = email_config.smtp_mailbox
        refresh_access_token(smtp_mailbox) if smtp_mailbox.authentication == Email::Mailbox::Constants::OAUTH &&
                                              access_token_expired?(smtp_mailbox) &&
                                              smtp_mailbox.error_type.nil?
        smtp_settings = {
          tls: smtp_mailbox.use_ssl,
          enable_starttls_auto: true,
          user_name: smtp_mailbox.user_name,
          password: smtp_mailbox.authentication == Email::Mailbox::Constants::OAUTH ? smtp_mailbox.access_token : smtp_mailbox.decrypt_password(smtp_mailbox.password),
          address: smtp_mailbox.server_name,
          port: smtp_mailbox.port,
          authentication: smtp_mailbox.authentication,
          domain: FRESHDESK_DOMAIN,
          return_response: true
        }
        Rails.logger.debug "Used SMTP mailbox : #{email_config.smtp_mailbox.user_name} in email config : #{email_config.id} while email delivery"
        self.smtp_settings = smtp_settings
        mail.delivery_method(:smtp, smtp_settings)
      elsif (email_config && email_config.category)
        Rails.logger.debug "Used EXISTING category : #{email_config.category} in email config : #{email_config.id} while email delivery"
        category_id = email_config.category
        set_smtp_settings_util(category_id)
        mail.delivery_method(:smtp, self.smtp_settings)
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type, note_id, from_email)
      else
        notification_type = is_num?(mail_type) ? mail_type : get_notification_type_id(mail_type) 
        params = { :account_id => account_id, :ticket_id => ticket_id, :type => notification_type, :note_id => note_id }
        category_id = get_notification_category_id(mail, notification_type)
        if category_id.blank?
          mailgun_traffic = get_mailgun_percentage
          if mailgun_traffic > 0 && Random::DEFAULT.rand(100) < mailgun_traffic
            category_id = reset_smtp_settings(mail, true)
          else
            category_id = reset_smtp_settings(mail)
          end
        else
          Rails.logger.debug "Fetched category : #{category_id} while email delivery"
          set_smtp_settings_util(category_id)
          mail.delivery_method(:smtp, self.smtp_settings)
        end
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type, note_id, from_email)
      end
      @email_confg = nil
      mail.header["X-FD-Email-Category"] = category_id
      # adding header for mentioning the type of email
      mail.header['X-EMAIL-TYPE'] = get_email_type mail_type
      mail.header['X-SOURCE'] = get_source mail if mail.header['X-SOURCE'].blank?
      mail.header['X-ACCOUNT-TYPE'] = get_account_type
    end

    def reset_smtp_settings(mail, use_mailgun = false)
      begin
        category_id = get_category_header(mail) || get_category_id(use_mailgun)
      rescue Exception => e
        Rails.logger.debug "Exception occurred while getting category id : #{e} - #{e.message} - #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
        category_id = nil
      end
      Rails.logger.debug "Fetched category : #{category_id} while email delivery"
      set_smtp_settings_util(category_id)
      mail.delivery_method(:smtp, self.smtp_settings)
      return category_id
    end
    def set_smtp_settings_util(category_id)
      smtp_settings = (read_smtp_settings(category_id)).merge!(:return_response => true)
      self.smtp_settings = smtp_settings
    end

    def set_custom_headers( mail, category_id, account_id, ticket_id, mail_type, note_id, from_email)
      if Helpdesk::Email::OutgoingCategory::MAILGUN_PROVIDERS.include?(category_id.to_i)
        Rails.logger.debug "Sending email via mailgun"
        message_id = encrypt_custom_variables(account_id, ticket_id, note_id, mail_type, from_email, category_id)
        mail.header['X-Mailgun-Variables'] = "{\"message_id\": \"#{message_id}\"}"
        mail.header['X-Mailgun-Rewrite-Sender-Header'] = false
      else
        Rails.logger.debug "Sending email via sendgrid"
        subject = !mail.header[:subject].nil? ? mail.header[:subject].value : "No Subject"
        smtpapi_hash = {
          "unique_args" => get_unique_args(from_email, account_id, ticket_id, note_id, mail_type, category_id)
        }
        mail.header['X-SMTPAPI'] = smtpapi_hash.to_json
        mail.header['X-CUSTOM-PARAMS'] = smtpapi_hash.to_json
      end
    rescue => e
      Rails.logger.debug "Error while setting custom headers - #{e.message} - #{e.backtrace}"
    end   
        
    def read_smtp_settings(category_id)
      email_config = Thread.current[:email_config]
      if ($redis_others.get("ROUTE_EMAILS_VIA_FD_SMTP_SERVICE") == "1" ||  (!(email_config.nil?)  && email_config.account.launched?(:deliver_email_via_fd_relay_server)))
        Rails.logger.info "Email has been sent via FD SMTP Service"
        Helpdesk::EMAIL["category-fd_email_service".to_sym][Rails.env.to_sym]
      else
        if (!category_id.nil?) && (!Helpdesk::EMAIL["category-#{category_id}".to_sym].nil?)
          Helpdesk::EMAIL["category-#{category_id}".to_sym][Rails.env.to_sym]
        else 
          Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
        end
      end
    end

    def get_category_header(mail)
      mail.header["X-FD-Email-Category"].to_s.to_i if mail.present? and mail.header["X-FD-Email-Category"].present? and mail.header["X-FD-Email-Category"].value.present?
    end

    def encrypt_custom_variables(account_id, ticket_id, note_id, type, from_email, category_id)
      type = (is_num?(type)) ? type : get_notification_type_id(type)
      account_id = (account_id == -1) ? 0 : account_id
      ticket_id = (ticket_id == -1) ? 0 : ticket_id
      note_id = (note_id == -1) ? 0 : note_id
      category_id = (category_id == -1) ? 0 : category_id
      from_email[from_email.rindex("@")] = "=" if from_email.present?
      shard_number = get_shard_number(account_id)
      pod_number = get_pod_number
      "#{account_id}.#{ticket_id}.#{note_id}.#{type}.#{category_id}.#{shard_number}.#{pod_number}+#{from_email}@freshdesk.com"
    end

    def decrypt_to_custom_variables(text)
      custom_string = text.gsub(/@freshdesk.com/, "")
      from_email = custom_string[custom_string.index("+") + 1, custom_string.length] #getting the very first '+'.
      from_email[from_email.rindex("=")] = "@" # replacing back the = with @. here very last '=' is considered, as no domain name can contain = in it.
      custom_string = custom_string[0, custom_string.index("+")]
      custom_variables = custom_string.split(".")
      type = get_notification_type_text(custom_variables[3])
      shard_name = get_shard_name(custom_variables[5])
      pod_name = get_pod_name(custom_variables[6])
      {
        :account_id =>  (custom_variables[0] == "0") ? -1 : custom_variables[0],
        :ticket_id => (custom_variables[1] == "0") ? -1 : custom_variables[1],
        :note_id => (custom_variables[2] == "0") ? -1 : custom_variables[2],
        :email_type => type.nil? ?  custom_variables[3] : type,
        :category_id => (custom_variables[4].present? && custom_variables[4] == "0") ? -1 : custom_variables[4],
        :shard_info => shard_name,
        :pod_info => pod_name,
        :from_email => from_email
      }
    end

    def get_notification_type_id(text)
        EmailNotificationConstants::NOTIFICATION_TYPES.key(text)
    end
    def get_notification_type_text(type)
        type = type.to_i
        EmailNotificationConstants::NOTIFICATION_TYPES[type]
    end

    def is_num?(str)
      !!Integer(str)
      rescue ArgumentError, TypeError
       false
    end

    def get_unique_args(from_email, account_id = -1, ticket_id = -1, note_id = -1, mail_type = "", category_id = -1)
      shard = get_shard account_id
      unique_args = {
        "account_id" => account_id,
        "ticket_id" => ticket_id,
        "email_type" => mail_type,
        "from_email" => from_email,
        "category_id" => category_id,
        "pod_info" => get_pod,
        "shard_info" => (shard.nil? ? "unknown" : shard.shard_name)
      }
      unique_args.merge!("note_id" => note_id) if(note_id != -1)

      unique_args
    end


    def get_notification_category_id(mail, notification_type)
      category_id = get_category_header(mail)
      return category_id if category_id.present?
      if custom_category_enabled_notifications.include?(notification_type.to_i)
        state = get_subscription
        key = (state == "active" || state == "premium") ? 'paid' : 'free'
        return Helpdesk::Email::OutgoingCategory::CATEGORY_BY_TYPE["#{key}_email_notification".to_sym]
      end
    end

    def get_pod
      PodConfig['CURRENT_POD']
    end
    def get_pod_number
      pod = get_pod
      EmailNotificationConstants::POD_TYPES.key(pod)
    end
    def get_shard account_id
      ShardMapping.fetch_by_account_id(account_id)
    end
    def get_shard_number(account_id)
      shard = get_shard account_id
      if shard.nil?
        return "0"
      else
        return shard.shard_name[6, shard.shard_name.length]
      end
    end

    def get_pod_name(text)
      pod_no = text.to_i
      EmailNotificationConstants::POD_TYPES[pod_no]
    end

    def get_shard_name(text)
      if text.to_i != 0
        return "shard_#{text}"
      end
    end

    def get_email_type(mail_type)
      if transaction_email_types.include? mail_type
        'TRANSACTION'
      elsif notification_email_types.include? mail_type
        'NOTIFICATION'
      else
        'SYSTEM'
      end
    end

    def transaction_email_types
      ['Reply', 'Forward', 'Reply to Forward', 'Notify Outbound Email']
    end

    def notification_email_types
      ['1', '4', '7', '8', '10', '25', '19', '20', '21', 'Email to Requestor', 'Internal Email', '15', '24', '201']
    end

    def get_account_type
      subscription = get_subscription
      if subscription.eql?('default')
        'MONITORING'
      else
        subscription.upcase
      end
    end

    def get_source(mail)
      if mail.present? && mail.header['X-SOURCE'].present? && mail.header['X-SOURCE'].value.present?
        mail.header['X-SOURCE'].to_s
      else
        'MONITORING'
      end
    end
  end
end

ActionMailer::Base.send :include, ActionMailerCallbacks

require 'auto_link_mail_interceptor'
ActionMailer::Base.register_interceptor(AutoLinkMailInterceptor)
