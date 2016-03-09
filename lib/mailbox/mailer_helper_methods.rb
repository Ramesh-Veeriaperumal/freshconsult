module Mailbox::MailerHelperMethods

  def configure_mailbox(user, portal)
    unless portal.blank? || portal.main_portal
      ActionMailer::Base.set_email_config portal.primary_email_config
    else
      ActionMailer::Base.set_email_config user.account.primary_email_config
    end
  end
end
