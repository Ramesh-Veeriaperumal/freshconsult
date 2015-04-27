class ForumErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ["shyam@freshdesk.com", "arvinth@freshdesk.com", "saranyaa@freshdesk.com"]

   def table_creation_failed(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => "rachel@freshdesk.com",
      :subject   =>  "Critical Error - Dynamo Table creation failed",
      :sent_on   => Time.now
    }
    @params = options
    @errors = options[:errors]
    mail(headers) do |part|
      part.html { render "table_creation_failed", :formats => [:html] }
    end.deliver
  end


end
