module Mailbox::MailerHelperMethods

  def configure_mailbox(user, portal)
    unless portal.blank? || portal.main_portal
      self.class.set_mailbox portal.primary_email_config.smtp_mailbox
    else
      self.class.set_mailbox user.account.primary_email_config.smtp_mailbox
    end
  end
  
end