class DataExportMailer < ActionMailer::Base
	
  layout "email_font"
  
  def data_backup(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Export for #{options[:domain]}"
    sent_on       Time.now
    body(:url => options[:url])
    content_type  "text/html"
  end 

  def ticket_export(options={})
    subject       "Ticket Exports for #{options[:domain]}"
    recipients    options[:user][:email]
    body          :user => options[:user], :url => options[:url]
    from          "support@freshdesk.com"
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "text/html"
  end

  def no_tickets(options={})
    subject       "No tickets in range - #{options[:domain]}"
    recipients    options[:user][:email]
    body          :user => options[:user]
    from          "support@freshdesk.com"
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "text/html"
  end
 

end
