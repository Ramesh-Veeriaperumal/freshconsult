module EmailNotificationConstants

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
  EMAIL_RATE_LIMITED_EXCEEDED = 112


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
    PHONE_TRIAL_NUMBER_DELETION_REMINDER_LAST_DAY =>  'phone_trial_number_deletion_reminder_last_day',
    EMAIL_RATE_LIMITED_EXCEEDED => 'Email rate limit exceeded'
  }

  EMAIL_SETTING_CONFIGS = (YAML::load_file(File.join(Rails.root, 'config', 'mailgun_out_going_email_mappings.yml')))[Rails.env]
  POD_TYPES = EMAIL_SETTING_CONFIGS["pod_types"]

  SPAM_FILTERED_NOTIFICATIONS = [ REPLY, FORWARD]

  RECENT_ACCOUNT_SPAM_FILTERED_NOTIFICATIONS = [ REPLY ]

  TICKET_SOURCE = [
    'EMAIL',
    'PORTAL',
    'PHONE',
    'FORUM',
    'TWITTER',
    'FACEBOOK',
    'CHAT',
    'MOBI_HELP',
    'FEEDBACK_WIDGET',
    'OUTBOUND_EMAIL',
    'ECOMMERCE',
    'BOT'
  ].freeze

  AGENT_INVITE_NOTIFICATION = {
    agent_subject_template: '{{portal_name}} agent invitation',
    agent_template: 'Hi {{agent.name}},<br /><br />Your {{helpdesk_name}} account has been created.<br /><br />Click <a href="{{helpdesk_url}}">here</a> to go to your account. <br /><br />If the above URL does not work, try copying and pasting it into your browser. Please feel free to contact us, if you continue to face any problems.<br /><br />Regards,<br />{{helpdesk_name}}'
  }

  DEFAULT_BOT_RESPONSE_TEMPLATE = {
    requester_subject_template: 'Re: {{ticket.subject}}',
    requester_template: "<div><div style='padding-bottom:18px;'>Hello {{ticket.requester.name}},</div>
    <div style='padding-bottom:18px;'> Thanks for reaching out! We've received your request -
    <a href='{{ticket.url}}'style= 'font-weight:normal; text-decoration:none; color:#448EE1; font-weight:normal; font-size:13px;'>
    {{ticket.id}}</a>, where you can check status and add comments. </div>
    <div style='padding-bottom:18px;'>While you wait, {{ticket.portal.bot_name}}, our friendly support sidekick found some answers for you. </div>
    {{freddy_suggestions}}
    Regards,
    <div>{{ticket.portal.name}}</div></div>"
  }.freeze
  
  DEFAULT_NR_REMINDER_TEMPLATE = {
    agent_template: '<p>Hi {{agent.firstname}},<br><br>Your response to ticket #{{ticket.id}} is due in {{ticket.nr_remaining_time}}. 
                    <br><br>Ticket Details: <br><br>Subject - {{ticket.subject}}<br>
                    <br>Requestor - {{ticket.requester.email}}<br><br>Ticket link - {{ticket.url}}<br><br>This is a 
                    reminder email from {{helpdesk_name}}</p>',
    agent_subject_template: 'Next Response due for - {{ticket.subject}}'
  }

  DEFAULT_NR_VIOLATION_TEMPLATE = {
    agent_template: '<p>Hi,<br><br>There has been no response to the customer for the ticket {{ticket.id}} . The response was due on {{ticket.nr_due_by_hrs}} today.<br>
                    <br>Ticket Details: <br><br>Subject - {{ticket.subject}}<br>
                    <br>Requestor - {{ticket.requester.email}}<br><br>This is an escalation email from {{helpdesk_name}}
                    <br>{{ticket.url}}</p>',
    agent_subject_template: 'Next Response time SLA violated - {{ticket.subject}}'
  }
end
