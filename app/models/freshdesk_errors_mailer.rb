class FreshdeskErrorsMailer < ActionMailer::Base
  
  def error_email(object, params, e, options={}) 
    recipients    "kiran@freshdesk.com"
    from          "rachel@freshdesk.com"
    subject       (options[:subject] || "Error in #{object.class.name}")
    sent_on       Time.now
    body(:object => object, :params => params, :error => e, :additional_info => options[:additional_info])
    content_type  "text/plain"
  end 
  
  def error_in_crm(account) 
    recipients    AppConfig['billing_email']
    from          "kiran@freshdesk.com"
    subject       "Error while adding to Capsule CRM"
    sent_on       Time.now
    body(:account => account)
    content_type  "text/html"
  end
  
end