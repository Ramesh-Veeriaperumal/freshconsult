class ForumErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ["community-team@freshdesk.com"]

   def table_operation_failed(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => "rachel@freshdesk.com",
      :subject   =>  "Critical Error - Dynamo Table operation failed",
      :sent_on   => Time.now
    }
    @params = options
    @errors = options[:errors]
    mail(headers) do |part|
      part.html { render "table_operation_failed", :formats => [:html] }
    end.deliver
  end


end
