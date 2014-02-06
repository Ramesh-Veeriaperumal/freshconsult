class Mailbox < ActiveRecord::Base

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  AUTHENTICATION_TYPES = [
    [:plain, "Plain"],
    [:login, "Login"],
    ["cram-md5".to_sym, "CRAM-MD5"]
  ]

  # Array defination
  # [key, name, server, imap_port, smtp_port]
  MAILBOX_SERVER_PROFILES = [
    [:gmail,      "Gmail",    I18n.t('mailbox.smtp_alert_gmail'),    25, "gmail.com", 993, 587],
    [:aol,        "AOL",      I18n.t('mailbox.smtp_alert_aol'),      3,  "aol.com",   993, 587],
    [:other,      "Other",    I18n.t('mailbox.smtp_alert_other'),    25]
  ]

  SERVER_PROFILES = MAILBOX_SERVER_PROFILES.map { |i| [i[1], i[0]] } 

  AUTHENTICATION_OPTIONS = AUTHENTICATION_TYPES.map { |a| [a[1], a[0]] }

  TIMEOUT_OPTIONS = Hash[Mailbox::MAILBOX_SERVER_PROFILES.collect { |i| [i[0], i[3]] }]

  def selected_server_profile
    selected_profile = MAILBOX_SERVER_PROFILES.select {|server| imap_server_name && imap_server_name.casecmp("imap.#{server[4]}") == 0}
    selected_profile.first.nil? ?  "other" : selected_profile.first[0].to_s
  end

  def smtp_domain
    smtp_user_name.split('@')[1] if !smtp_user_name.blank? && smtp_user_name.include?("@")
  end

  def decrypt_password mailbox_password
    private_key_file = 'config/cert/private.pem'
    password = 'freshprivate'
    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file),password)
    return private_key.private_decrypt(Base64.decode64(mailbox_password))
  end

  def imap_params(timestamp)
    { :mailbox_attributes => { :id => id,
        :user_name => imap_user_name,
        :password => imap_password,
        :server_name => imap_server_name,
        :server_port => imap_port,
        :authentication => imap_authentication,
        :delete_from_server => imap_delete_from_server,
        :folder => imap_folder,
        :use_ssl => imap_use_ssl,
        :to_email => email_config.to_email,
        :account_id => account_id,
        :time_zone => account.time_zone,
        :timeout => imap_timeout
      },
      :timestamp => timestamp
      }.to_json
  end
end
