class FreshdeskErrorsMailer < ActionMailer::Base
  
  def error_email(object,params,e,exinfo=nil)
    recipients    "support@freshdesk.com"
    from          "support@freshdesk.com"
    subject       "Error in #{object.class.name}"
    sent_on       Time.now
    body(:object => object,:params => params,:error => e,:exinfo => exinfo)
    content_type  "text/html"
  end 
  

end