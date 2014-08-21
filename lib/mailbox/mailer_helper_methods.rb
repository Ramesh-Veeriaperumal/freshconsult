module Mailbox::MailerHelperMethods

  def configure_mailbox(user, portal)
    unless portal.blank? || portal.main_portal
      ActionMailer::Base.set_mailbox portal.primary_email_config.smtp_mailbox
    else
      ActionMailer::Base.set_mailbox user.account.primary_email_config.smtp_mailbox
    end
  end
end
