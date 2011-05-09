class DataExportMailer < ActionMailer::Base
  
  def export_email(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Export for #{options[:domain]}"
    sent_on       Time.now
    body(:url => options[:url])
    content_type  "text/plain"
  end 

end