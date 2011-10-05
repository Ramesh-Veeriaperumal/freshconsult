class Admin::DataImportMailer < ActionMailer::Base
  
 def import_email(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Import for #{options[:domain]}"
    sent_on       Time.now
    body          (options)
    content_type  "text/html"
  end 
  
   def import_error_email(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Import for #{options[:domain]}"
    sent_on       Time.now
    body          (options)
    content_type  "text/html"
  end 
  
  
end