class FreshdeskErrorsMailer < ActionMailer::Base
  
  def error_email(object, params, e, options={}) 
    recipients    "support@freshdesk.com"
    from          "support@freshdesk.com"
    subject       (options[:subject] || "Error in #{object.class.name}")
    sent_on       Time.now
    body(:object => object, :params => params, :error => e, :additional_info => options[:additional_info])
    content_type  "text/plain"
  end 

end