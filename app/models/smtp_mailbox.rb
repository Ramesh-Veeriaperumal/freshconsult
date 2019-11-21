class SmtpMailbox < ActiveRecord::Base
  include Mailbox::HelperMethods

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id
end