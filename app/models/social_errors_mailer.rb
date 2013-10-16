class SocialErrorsMailer < ActionMailer::Base
  
  layout "email_font"
  
  RECIPIENTS = ["revathi@freshdesk.com","arvind@freshdesk.com"]
  
  
  def threshold_reached(options={}) 
    recipients    RECIPIENTS           
    from          "rachel@freshdesk.com"
    subject       "Critical Error - Threshold reached in SQS"
    sent_on       Time.now
    body          (:params => options)
    content_type  "text/html"
  end 
  
  def mismatch_in_rules(options)
    recipients RECIPIENTS
    from       "rachel@freshdesk.com"
    subject    "Critical Error - Mismatch of rules in Gnip"
    sent_on    Time.now
    body      (:params => options)
    content_type "text/html"
  end
  
  def gnip_stream_reconnected(options)
    recipients RECIPIENTS
    from       "rachel@freshdesk.com"
    subject    "Critical Error - Gnip stream reconnected"
    sent_on    Time.now
    body      (:params => options)
    content_type "text/html"
  end
end