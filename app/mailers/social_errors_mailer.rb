class SocialErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ["fd-social-team@freshworks.com", "arvind@freshdesk.com", "sumankumar@freshdesk.com",  "krishnanand.balasubramanian@freshworks.com"]


  def threshold_reached(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => "rachel@freshdesk.com",
      :subject   =>  "Critical Error - Threshold reached in SQS",
      :sent_on   => Time.now
    }
    @params = options
    mail(headers) do |part|
      part.html { render "threshold_reached", :formats => [:html] }
    end.deliver
  end

  def facebook_exception(options, params=nil)
    headers = {
      :to          => RECIPIENTS,
      :from        => "rachel@freshdesk.com",
      :subject     => "Critical Error - Facebook Exception",
      :sent_on     => Time.now
    }
    @error = options
    @params = params
    mail(headers) do |part|
      part.html { render "facebook_exception", :formats => [:html] }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
