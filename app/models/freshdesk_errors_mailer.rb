class FreshdeskErrorsMailer < ActionMailer::Base
  
  layout "email_font"
  
  def error_email(object, params, e, options={}) 
    recipients    (options[:recipients] || (Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : "dev-ops@freshpo.com") )
    from          Helpdesk::EMAIL[:default_requester_email]
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

  def spam_watcher(options={}) 
    recipients    Helpdesk::EMAIL[:spam_watcher]
    from          Helpdesk::EMAIL[:default_requester_email]
    subject       (options[:subject] || "Abnormal load by spam watcher")
    sent_on       Time.now
    body(:additional_info => options[:additional_info])
    content_type  "text/html"
  end 

  def spam_blocked_alert(options={}) 
    recipients    Helpdesk::EMAIL[:spam_watcher]
    from          Helpdesk::EMAIL[:default_requester_email]
    subject       (options[:subject] || "Abnormal load by spam watcher")
    sent_on       Time.now
    body(:additional_info => options[:additional_info])
    content_type  "text/html"
  end 
  
end