module Mailbox::MailerHelperMethods

include EmailHelper

  def configure_mailbox(user, portal)
    unless portal.blank? || portal.main_portal
      configure_email_config portal.primary_email_config
    else
      configure_email_config user.account.primary_email_config
    end
  end
end
