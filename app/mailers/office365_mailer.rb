class Office365Mailer < ActionMailer::Base

  def email_to_outlook(options={})
    headers = {
      :to           =>  options[:recipient],
      :from         =>  AppConfig["office365_email"],
      "Reply-to"    =>  options[:reply_email],
      :subject      =>  options[:subject],
      :sent_on      =>  Time.now
    }
    mail(headers) do |part|
      part.html { options[:html] }
    end.deliver
  end
end
