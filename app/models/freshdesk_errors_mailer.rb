class FreshdeskErrorsMailer < ActionMailer::Base
  
  layout "email_font"
  
  def error_email(object, params, e, options={}) 
    recipients    "dev-ops@freshdesk.com"
    from          "rachel@freshdesk.com"
    subject       (options[:subject] || "Error in #{object.class.name}")
    sent_on       Time.now
    body(:object => object, :params => params, :error => e, :additional_info => options[:additional_info], :query => options[:query])
    content_type  "text/html"
  end 
  
  def error_in_crm(model) 
    recipients    AppConfig['billing_email']
    from          "kiran@freshdesk.com"
    cc            "vijayaraj@freshdesk.com"
    subject       "Error while adding to Marketo"
    sent_on       Time.now
    body(:model => model)
    content_type  "text/html"
  end
  
end