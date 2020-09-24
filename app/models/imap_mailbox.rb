# frozen_string_literal: true

class ImapMailbox < ActiveRecord::Base
  include Email::Mailbox::Constants
  include Mailbox::HelperMethods

  include EmailHelper

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  self.primary_key = :id

  scope :errors, -> { where('error_type > ? and error_type <> ?', 0, IMAP_AUTH_ERROR) }
  scope :reauth_errors, -> { where('error_type = ?', IMAP_AUTH_ERROR) }

  attr_encrypted :access_token, random_iv: true, compress: true
  attr_encrypted :refresh_token, random_iv: true, compress: true
  validates :encrypted_access_token, symmetric_encryption: true, if: :oauth_mailbox?
  validates :encrypted_refresh_token, symmetric_encryption: true, if: :oauth_mailbox?

  def selected_server_profile
    selected_profile = MailboxConstants::MAILBOX_SERVER_PROFILES.select {|server| server_name && server_name.casecmp("imap.#{server[4]}") == 0}
    selected_profile.first.nil? ?  "other" : selected_profile.first[0].to_s
  end

  def imap_params(action)
    shard = ShardMapping.lookup_with_account_id(account_id)
    pod_info = shard.present? ? shard.pod_info : PodConfig['CURRENT_POD']

    imap_params_hash = { mailbox_attributes: { id: id,
                                               user_name: user_name,
                                               password: password,
                                               server_name: server_name,
                                               server_port: port,
                                               authentication: authentication,
                                               delete_from_server: delete_from_server,
                                               folder_list: { 'standard' => ['inbox'] },
                                               use_ssl: use_ssl,
                                               to_email: email_config.to_email,
                                               account_id: account_id,
                                               time_zone: account.time_zone,
                                               timeout: timeout,
                                               pod_info: pod_info,
                                               domain: account.full_domain,
                                               application_id: imap_application_id },
                         action: action }
    if oauth_mailbox?
      server_key = server_name.include?(GMAIL) ? GMAIL : OFFICE365
      email_provider_type = IMAP_PROVIDER_NAME_BY_SERVER_KEY[server_key]
      imap_params_hash[:mailbox_attributes][:password] = refresh_token
      imap_params_hash[:mailbox_attributes][:email_provider_type] = email_provider_type
      imap_params_hash[:mailbox_attributes][:password_enc_algorithm] = PLAIN
    end
    imap_params_hash.to_json
  end

  def oauth_mailbox?
    authentication == OAUTH
  end
end
