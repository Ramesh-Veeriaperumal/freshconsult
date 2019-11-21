class SmtpMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods

  def before_create mailbox
    set_account mailbox
    encrypt_password mailbox
    encrypt_refresh_token mailbox
  end

  def before_update mailbox
    encrypt_password mailbox
    encrypt_refresh_token mailbox
  end
end