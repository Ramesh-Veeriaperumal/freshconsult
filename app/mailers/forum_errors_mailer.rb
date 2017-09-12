class ForumErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ["community-team@freshdesk.com", "fd-suicide-squad@freshdesk.com"]
  FROM = "sajesh.krishnadas@freshworks.com"

   def table_operation_failed(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => FROM,
      :subject   => "Critical Error - Dynamo Table operation failed",
      :sent_on   => Time.now
    }
    @params = options
    @errors = options[:errors]
    mail(headers) do |part|
      part.html { render "table_operation_failed", :formats => [:html] }
    end.deliver
  end

  def forum_moderation_failed(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => FROM,
      :subject   => "Error: Forum Moderation",
      :sent_on   => Time.now
    }
    @error = options[:error]
    @message = options[:message]
    mail(headers) do |part|
      part.html { render "forum_moderation_failed", :formats => [:html] }
    end.deliver
  end

end
