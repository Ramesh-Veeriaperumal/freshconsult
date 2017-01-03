class CloudLogMailer < ActionMailer::Base
  layout "email_font"

  def cloud_log_email(options={})
    headers = {
      :to           =>  options[:recipients],
      :from         =>  AppConfig["from_email"],
      :subject      =>  options[:subject],
      :sent_on      =>  Time.now,
      :bcc      => options[:bcc_recipients]
    }
    @size = options[:size]
    @failure_reasons = options[:failure_reasons]
    mail(headers) do |part|
      part.html { render "logger_email" }
    end.deliver
  end
end
