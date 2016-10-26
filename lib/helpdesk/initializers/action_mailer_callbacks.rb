require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks

  def self.included(base)
    base.extend ClassMethods
    base.extend Helpdesk::Email::OutgoingCategory
  end

  module ClassMethods

 # Email notification constants as part of adding custom variables in the email headers(for Mailgun)

    REQUEST_FRESHFONE_FEATURE = 25
    PREVIEW_EMAIL = 26
    IMPORT_EMAIL = 27
    IMPORT_ERROR_EMAIL = 28
    IMPORT_FORMAT_ERROR_EMAIL = 29
    IMPORT_SUMMARY = 30
    GOOGLE_CONTACTS_IMPORT_EMAIL = 31
    DATA_BACKUP = 32
    TICKET_EXPORT = 33
    NO_TICKETS = 34
    CUSTOMER_EXPORT = 35
    REPORTS_EXPORT = 36
    AGENT_EXPORT = 37
    BROADCAST_MESSAGE = 38
    EMAIL_CONFIG_ACTIVATION_INSTRUCTIONS = 39
    FRESHDESK_TEST_EMAIL = 40
    ACCOUNT_EXPIRING = 41
    NUMBER_RENEWAL_FAILURE = 42
    SUSPENDED_ACCOUNT = 43
    RECHARGE_SUCCESS = 44
    LOW_BALANCE = 45
    TRIAL_NUMBER_EXPIRING = 46
    BILLING_FAILURE = 47
    RECHARGE_FAILURE = 48
    OPS_ALERT = 49
    FRESHFONE_OPS_NOTIFIER = 50
    ACCOUNT_CLOSING = 51
    CALL_RECORDING_DELETION_FAILURE = 52
    PHONE_TRIAL_REMINDER = 53
    REPLY = 54
    FORWARD = 55
    REPLY_TO_FORWARD = 56
    EMAIL_TO_REQUESTOR = 57
    INTERNAL_EMAIL = 58
    NOTIFY_OUTBOUND_EMAIL = 59
    NOTIFY_NEW_WATCHER = 60
    NOTIFY_ON_REPLY = 61
    NOTIFY_ON_STATUS_CHANGE = 62
    MONITOR_EMAIL = 63
    BI_REPORT_EXPORT = 64 
    NO_REPORT_DATA = 65
    EXCEEDS_FILE_SIZE_LIMIT = 66
    REPORT_EXPORT_TASK = 67
    EXPIRED_TASK = 68
    NOTIFY_BLOCKED_OR_DELETED = 69
    NOTIFY_DOWNGRADED_USER = 70
    EMAIL_SCHEDULED_REPORT = 71
    REPORT_NO_DATA_EMAIL = 72
    AGENT_ALERT_EMAIL = 73
    ADMIN_ALERT_EMAIL = 74
    SUBSCRIPTION_ERROR = 75
    WELCOME = 76
    TRIAL_EXPIRING = 77
    CHARGE_RECEIPT = 78
    DAY_PASS_RECEIPT = 79
    MISC_RECEIPT = 80
    CHARGE_FAILURE = 81
    ACCOUNT_DELETED = 82
    ADMIN_SPAM_WATCHER = 83
    ADMIN_SPAM_WATCHER_BLOCKED = 84
    SUBSCRIPTION_DOWNGRADED = 85
    SALESFORCE_FAILURES = 86
    TOPICMAILER_MONITOR_EMAIL = 87
    STAMP_CHANGE_EMAIL = 88
    TOPIC_MERGE_EMAIL = 89
    EMAIL_ACTIVATION = 90
    ADMIN_ACTIVATION = 91
    CUSTOM_SSL_ACTIVATION = 92
    NOTIFY_CUSTOMERS_IMPORT = 93
    NOTIFY_FACEBOOK_REAUTH = 94
    NOTIFY_WEBHOOK_FAILURE = 95
    NOTIFY_WEBHOOK_DROP = 96
    HELPDESK_URL_REMINDER = 97
    ONE_TIME_PASSWORD = 98
    FAILURE_TRANSACTION_NOTIFIER = 99
    DISCARD_EMAIL = 100
    TOKEN_EXPIRY = 101
    NOTIFY_THRESHOLD_LIMIT = 102
    DAILY_API_USAGE = 103
    SPAM_DIGEST = 104
    CALL_HISTORY_EXPORT = 105
    PHONE_TRIAL_INITIATED = 106
    PHONE_TRIAL_HALF_WAY = 107
    PHONE_TRIAL_ABOUT_TO_EXPIRE = 108
    PHONE_TRIAL_EXPIRE = 109
    PHONE_TRIAL_NUMBER_DELETION_REMINDER = 110
    PHONE_TRIAL_NUMBER_DELETION_REMINDER_LAST_DAY = 111


    NOTIFICATION_TYPES = {

      REQUEST_FRESHFONE_FEATURE =>  "Request Freshfone Feature",
      PREVIEW_EMAIL =>  "Preview Email",
      IMPORT_EMAIL =>  "Import Email",
      IMPORT_ERROR_EMAIL =>  "Import Error Email",
      IMPORT_FORMAT_ERROR_EMAIL =>  "Import Format Error Email",
      IMPORT_SUMMARY =>  "Import Summary",
      GOOGLE_CONTACTS_IMPORT_EMAIL =>  "Google Contacts Import Email",
      DATA_BACKUP =>  "Data Backup",
      TICKET_EXPORT =>  "Ticket Export",
      NO_TICKETS =>  "No Tickets",
      CUSTOMER_EXPORT =>  "Customer Export",
      REPORTS_EXPORT =>  "Reports Export",
      AGENT_EXPORT =>  "Agent Export",
      BROADCAST_MESSAGE =>  "Broadcast Message",
      EMAIL_CONFIG_ACTIVATION_INSTRUCTIONS =>  "Email Config Activation Instructions",
      FRESHDESK_TEST_EMAIL =>  "Freshdesk Test Email",
      ACCOUNT_EXPIRING =>  "Account Expiring",
      NUMBER_RENEWAL_FAILURE =>  "Number Renewal Failure",
      SUSPENDED_ACCOUNT =>  "Suspended Account",
      RECHARGE_SUCCESS =>  "Recharge Success",
      LOW_BALANCE =>  "Low Balance",
      TRIAL_NUMBER_EXPIRING =>  "Trial Number Expiring",
      BILLING_FAILURE =>  "Billing Failure",
      RECHARGE_FAILURE =>  "Recharge Failure",
      OPS_ALERT =>  "Ops Alert",
      FRESHFONE_OPS_NOTIFIER =>  "Freshfone Ops Notifier",
      ACCOUNT_CLOSING =>  "Account Closing",
      CALL_RECORDING_DELETION_FAILURE =>  "Call Recording Deletion Failure",
      PHONE_TRIAL_REMINDER =>  "Phone Trial Reminder",
      REPLY =>  "Reply",
      FORWARD =>  "Forward",
      REPLY_TO_FORWARD =>  "Reply to Forward",
      EMAIL_TO_REQUESTOR =>  "Email to Requestor",
      INTERNAL_EMAIL =>  "Internal Email",
      NOTIFY_OUTBOUND_EMAIL =>  "Notify Outbound Email",
      NOTIFY_NEW_WATCHER =>  "Notify New Watcher",
      NOTIFY_ON_REPLY =>  "Notify On Reply",
      NOTIFY_ON_STATUS_CHANGE =>  "Notify On Status Change",
      MONITOR_EMAIL =>  "Monitor Email",
      BI_REPORT_EXPORT =>  "Bi Report Export",
      NO_REPORT_DATA =>  "No Report Data",
      EXCEEDS_FILE_SIZE_LIMIT =>  "Exceeds File Size Limit",
      REPORT_EXPORT_TASK =>  "Report Export Task",
      EXPIRED_TASK =>  "Expired Task",
      NOTIFY_BLOCKED_OR_DELETED =>  "Notify Blocked or Deleted",
      NOTIFY_DOWNGRADED_USER =>  "Notify Downgraded User",
      EMAIL_SCHEDULED_REPORT =>  "Email Scheduled Report",
      REPORT_NO_DATA_EMAIL =>  "Report No Data Email",
      AGENT_ALERT_EMAIL =>  "Agent Alert Email",
      ADMIN_ALERT_EMAIL =>  "Admin Alert Email",
      SUBSCRIPTION_ERROR =>  "Subscription Error",
      WELCOME =>  "Welcome",
      TRIAL_EXPIRING =>  "Trial Expiring",
      CHARGE_RECEIPT =>  "Charge Receipt",
      DAY_PASS_RECEIPT =>  "Day Pass Receipt",
      MISC_RECEIPT =>  "Misc Receipt",
      CHARGE_FAILURE =>  "Charge Failure",
      ACCOUNT_DELETED =>  "Account Deleted",
      ADMIN_SPAM_WATCHER =>  "Admin Spam Watcher",
      ADMIN_SPAM_WATCHER_BLOCKED =>  "Admin Spam Watcher Blocked",
      SUBSCRIPTION_DOWNGRADED =>  "Subscription Downgraded",
      SALESFORCE_FAILURES =>  "Salesforce Failures",
      TOPICMAILER_MONITOR_EMAIL =>  "TopicMailer Monitor Email",
      STAMP_CHANGE_EMAIL =>  "Stamp Change Email",
      TOPIC_MERGE_EMAIL =>  "Topic merge Email",
      EMAIL_ACTIVATION =>  "Email Activation",
      ADMIN_ACTIVATION =>  "Admin Activation",
      CUSTOM_SSL_ACTIVATION =>  "Custom SSL Activation",
      NOTIFY_CUSTOMERS_IMPORT =>  "Notify Customers Import",
      NOTIFY_FACEBOOK_REAUTH =>  "Notify Facebook Reauth",
      NOTIFY_WEBHOOK_FAILURE =>  "Notify Webhook Failure",
      NOTIFY_WEBHOOK_DROP =>  "Notify Webhook Drop",
      HELPDESK_URL_REMINDER =>  "Helpdesk Url Reminder",
      ONE_TIME_PASSWORD =>  "One Time Password",
      FAILURE_TRANSACTION_NOTIFIER =>  "Failure Transaction Notifier",
      DISCARD_EMAIL =>  "Discard Email",
      TOKEN_EXPIRY =>  "Token Expiry",
      NOTIFY_THRESHOLD_LIMIT =>  "Notify Threshold Limit",
      DAILY_API_USAGE =>  "Daily API Usage",
      SPAM_DIGEST =>  "Spam Digest",
      CALL_HISTORY_EXPORT =>  "Call history Export",
      PHONE_TRIAL_INITIATED =>  "phone_trial_initiated",
      PHONE_TRIAL_HALF_WAY =>  "phone_trial_half_way",
      PHONE_TRIAL_ABOUT_TO_EXPIRE =>  "phone_trial_about_to_expire",
      PHONE_TRIAL_EXPIRE =>  "phone_trial_expire",
      PHONE_TRIAL_NUMBER_DELETION_REMINDER =>  "phone_trial_number_deletion_reminder",
      PHONE_TRIAL_NUMBER_DELETION_REMINDER_LAST_DAY =>  "phone_trial_number_deletion_reminder_last_day" 
    }


    @email_confg = nil
        
    def set_email_config _email_config
      @email_confg = _email_config
    end
    
    def email_config
      @email_confg
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

      if (email_config && email_config.smtp_mailbox)
        smtp_mailbox = email_config.smtp_mailbox
        smtp_settings = {
          :tls                  => smtp_mailbox.use_ssl,
          :enable_starttls_auto => true,
          :user_name            => smtp_mailbox.user_name,
          :password             => smtp_mailbox.decrypt_password(smtp_mailbox.password),
          :address              => smtp_mailbox.server_name,
          :port                 => smtp_mailbox.port,
          :authentication       => smtp_mailbox.authentication,
          :domain               => smtp_mailbox.domain
        }
        Rails.logger.debug "Used SMTP mailbox : #{email_config.smtp_mailbox.user_name} in email config : #{email_config.id} while email delivery"
        self.smtp_settings = smtp_settings
        mail.delivery_method(:smtp, smtp_settings)
      elsif (email_config && email_config.category)
        Rails.logger.debug "Used EXISTING category : #{email_config.category} in email config : #{email_config.id} while email delivery"
        category_id = email_config.category
        self.smtp_settings = read_smtp_settings(category_id)
        mail.delivery_method(:smtp, read_smtp_settings(category_id))
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type,note_id)
      else
        mailgun_traffic = get_mailgun_percentage
        if mailgun_traffic > 0 && Random::DEFAULT.rand(100) < mailgun_traffic
          category_id = reset_smtp_settings(mail, true)
        else
          category_id = reset_smtp_settings(mail)
        end
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type,note_id)
      end
      @email_confg = nil
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
      self.smtp_settings = read_smtp_settings(category_id)
      mail.delivery_method(:smtp, read_smtp_settings(category_id))
      return category_id
    end

    def set_custom_headers(mail, category_id, account_id, ticket_id, mail_type, note_id)
      if category_id.to_i > 10
        Rails.logger.debug "Sending email via mailgun"
        message_id = encrypt_custom_variables(account_id, ticket_id, note_id, mail_type)
        mail.header['X-Mailgun-Variables'] = "{\"message_id\": \"#{message_id}\"}"
      else
        Rails.logger.debug "Sending email via sendgrid"
        mail.header['X-SMTPAPI'] = "{\"unique_args\":{\"account_id\": #{account_id},\"ticket_id\":#{ticket_id},\"note_id\": #{note_id},\"type\":\"#{mail_type}\"}}"
      end
    end   
        
    def read_smtp_settings(category_id)
      if (!category_id.nil?) && (!Helpdesk::EMAIL["category-#{category_id}".to_sym].nil?)
        Helpdesk::EMAIL["category-#{category_id}".to_sym][Rails.env.to_sym]
      else 
        Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
      end
    end

    def get_category_header(mail)
      mail.header["X-FD-Email-Category"].to_s.to_i if mail.present? and mail.header["X-FD-Email-Category"].present?
    end

    def encrypt_custom_variables(account_id, ticket_id, note_id, type)
      type = (is_num?(type)) ? type : get_notification_type_id(type)
      account_id = (account_id == -1) ? 0 : account_id
      ticket_id = (ticket_id == -1) ? 0 : ticket_id
      note_id = (note_id == -1) ? 0 : note_id

      "#{account_id}.#{ticket_id}.#{note_id}.#{type}@freshdesk.com"
    end

    def decrypt_to_custom_variables(text)
      custom_string = text.gsub(/@freshdesk.com/, "")
      custom_variables = custom_string.split(".")
      type = get_notification_type_text(custom_variables[3])

      {
        :account_id =>  (custom_variables[0] == "0") ? -1 : custom_variables[0],
        :ticket_id => (custom_variables[1] == "0") ? -1 : custom_variables[1],
        :note_id => (custom_variables[2] == "0") ? -1 : custom_variables[2],
        :type => type.nil? ?  custom_variables[3] : type
      }
    end

    def get_notification_type_id(text)
        NOTIFICATION_TYPES.key(text)
    end
    def get_notification_type_text(type)
        type = type.to_i
        NOTIFICATION_TYPES[type]
    end

    def is_num?(str)
      !!Integer(str)
      rescue ArgumentError, TypeError
       false
    end
  end
end

ActionMailer::Base.send :include, ActionMailerCallbacks

require 'auto_link_mail_interceptor'
ActionMailer::Base.register_interceptor(AutoLinkMailInterceptor)
