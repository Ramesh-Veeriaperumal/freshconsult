module MailboxConstants
  AUTHENTICATION_TYPES = [
    [:plain, "Plain"],
    [:login, "Login"],
    ["cram-md5".to_sym, "CRAM-MD5"]
  ]

  # Array defination
  # [key, name, alert_mesage, timeout, server, imap_port, smtp_port]
  MAILBOX_SERVER_PROFILES = [
    [:gmail,      "Gmail",    I18n.t('mailbox.smtp_alert_gmail'),    25, "gmail.com", 993, 587],
    [:aol,        "AOL",      I18n.t('mailbox.smtp_alert_aol'),      3,  "aol.com",   993, 587],
    [:other,      "Other",    I18n.t('mailbox.smtp_alert_other'),    4]
  ]

  SERVER_PROFILES = MAILBOX_SERVER_PROFILES.map { |i| [i[1], i[0]] } 

  AUTHENTICATION_OPTIONS = AUTHENTICATION_TYPES.map { |a| [a[1], a[0]] }

  TIMEOUT_OPTIONS = Hash[MAILBOX_SERVER_PROFILES.collect { |i| [i[0], i[3]] }]
end