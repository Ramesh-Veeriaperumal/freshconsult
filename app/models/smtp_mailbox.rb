class SmtpMailbox < ActiveRecord::Base
  include Mailbox::HelperMethods
  include Email::Mailbox::Constants

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  scope :errors, -> { where('error_type > ? and error_type NOT IN (?)', 0, SMTP_REAUTH_ERRORS) }
  scope :reauth_errors, -> { where('error_type IN (?)', SMTP_REAUTH_ERRORS) }

  attr_encrypted :access_token, random_iv: true, compress: true
  attr_encrypted :refresh_token, random_iv: true, compress: true
  validates :encrypted_access_token, symmetric_encryption: true, if: :oauth_mailbox?
  validates :encrypted_refresh_token, symmetric_encryption: true, if: :oauth_mailbox?

  def oauth_mailbox?
    authentication == Email::Mailbox::Constants::OAUTH
  end
end
