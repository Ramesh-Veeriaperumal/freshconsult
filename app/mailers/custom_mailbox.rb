class CustomMailbox < ActionMailer::Base
  layout "email_font"

  def error(email_hash, options = {})
    headers = {
      :to           =>  email_hash[:group],
      :from         =>  AppConfig["from_email"],
      :subject      =>  I18n.t("custom_mailbox_admin_email_notifications.subject")
    }
    
    @other_emails = email_hash[:other]
    @email_mailbox = options[:email_mailbox]
    mail(headers) do |part|
      part.html { render "error" }
    end.deliver
  end
end
