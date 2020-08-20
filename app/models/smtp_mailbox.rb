class SmtpMailbox < ActiveRecord::Base
  include Mailbox::HelperMethods
  include Email::Mailbox::Constants

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  scope :errors, -> { where('error_type > ? and error_type <> ?', 0, AUTH_ERROR) }
  scope :oauth_errors, -> { where('error_type = ?', AUTH_ERROR) }
end
