class CustomMailbox < ActionMailer::Base
  layout "email_font"

  def error(options={})
    headers = {
      :to           =>  options[:to_emails],
      :from         =>  AppConfig["from_email"],
      :subject      =>  options[:subject]
    }
    
    @email_mailbox = options[:email_mailbox]
    mail(headers) do |part|
      part.html { render "error" }
    end.deliver
  end
end
