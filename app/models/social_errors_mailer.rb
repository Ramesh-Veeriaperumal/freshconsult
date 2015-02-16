class SocialErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ["revathi@freshdesk.com","arvind@freshdesk.com","sumankumar@freshdesk.com", "sukanya@freshdesk.com"]


  def threshold_reached(options={})
    recipients    RECIPIENTS
    from          "rachel@freshdesk.com"
    subject       "Critical Error - Threshold reached in SQS"
    sent_on       Time.now
    body          ({:params => options})
    content_type  "text/html"
  end

  def facebook_exception(options, params=nil)
    recipients RECIPIENTS
    from       "rachel@freshdesk.com"
    subject    "Critical Error - Facebook Exception"
    sent_on    Time.now
    body(:error =>options, :params => params)
    content_type "text/html"
  end
end
