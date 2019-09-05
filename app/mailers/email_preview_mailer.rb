class EmailPreviewMailer < ActionMailer::Base

  layout "email_font"

  def send_test_email(mail_body, subject, to_email)
    @body = mail_body
    subject ||= I18n.t('email_notifications.preview_message')
    @headers = {
      :from    => Account.current.default_friendly_email,
      :to      => to_email,
      :subject => I18n.t('email_notifications.preview_mail_prefix') + subject,
      :sent_on => Time.now
    }
    mail(@headers) do |part|
      part.text { render "/email_preview/email_preview.text.plain.erb" }
      part.html { render "/email_preview/email_preview.text.html.erb" }
    end.deliver
  end

  include MailerDeliverAlias 

end