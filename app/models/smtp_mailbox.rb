class SmtpMailbox < ActiveRecord::Base
  include Mailbox::HelperMethods

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  scope :errors, -> { where('error_type > ?', 0) }

  attr_encrypted :access_token, random_iv: true, compress: true
  attr_encrypted :refresh_token, random_iv: true, compress: true
  validates :encrypted_access_token, symmetric_encryption: true, if: -> { authentication == Email::Mailbox::Constants::OAUTH }
  validates :encrypted_refresh_token, symmetric_encryption: true, if: -> { authentication == Email::Mailbox::Constants::OAUTH }
end
