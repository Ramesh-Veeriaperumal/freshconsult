class DataExportMailer < ActionMailer::Base
	
  layout "email_font"
  
  def export_email(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Export for #{options[:domain]}"
    sent_on       Time.now
    body(:url => options[:url])
    content_type  "text/html"
  end 

end
