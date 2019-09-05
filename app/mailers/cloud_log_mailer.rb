class CloudLogMailer < ActionMailer::Base
  layout "email_font"

  def cloud_log_email(email_hash, options = {})
    headers = {
      :to           =>  email_hash[:group],
      :from         =>  AppConfig["from_email"],
      :subject      =>  t("mailer_notifier_subject.#{options[:subject_key]}", app_name: options[:app_name]),
      :sent_on      =>  Time.now
    }
    @other_emails = email_hash[:other]
    @size = options[:size]
    @subdomain = options[:subdomain]
    @failure_reasons = options[:failure_reasons]
    mail(headers) do |part|
      part.html { render "logger_email" }
    end.deliver
  end
end
