class Admin::DataImportMailer < ActionMailer::Base

  layout "email_font"
  
 def import_email(options={}) 
    recipients    options[:email]
    from          "support@freshdesk.com"
    subject       "Data Import for #{options[:domain]}"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body          (options.merge({ :account => Account.current }))
    content_type  "text/html"
  end 
  
   def import_error_email(options={}) 
    recipients    options[:user][:email]
    from          "support@freshdesk.com"
    subject       "Data Import for #{options[:domain]}"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body          :user => options[:user][:name], :account => Account.current
    content_type  "text/html"
  end 

  def import_format_error_email(options={}) 
    recipients    options[:user][:email]
    from          "support@freshdesk.com"
    subject       "Data Import for #{options[:domain]}"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body          :user => options[:user][:name], :account => Account.current
    content_type  "text/html"
  end

  def import_summary(options={})
    recipients    options[:user][:email]
    from          "support@freshdesk.com"
    subject       "Import from Zendesk successful"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body          :user => options[:user][:name], :account => Account.current
    content_type  "text/html"
  end 

  def customers_import_with_failure(options={})
    recipients    options[:user].email
    from          "support@freshdesk.com"
    subject       "#{options[:type]} Import for #{options[:domain]}"
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    body          :user => options[:user], :url => options[:url], :type => options[:type], :account => Account.current
    content_type  "text/html"
  end
  
  def google_contacts_import_email(options)
    @last_stats = options[:status]
    set_default_mail_options options[:email], "Successfully imported Google contacts for #{options[:domain]}"
    body          (options.merge({ :account => Account.current }))
  end

  def google_contacts_import_error_email(options)
    set_default_mail_options options[:email], "Error in importing Google contacts for #{options[:domain]}"
    body          (options.merge({ :account => Account.current }))
  end

  private
    def set_default_mail_options(to_email, subject)
      from          "support@freshdesk.com"
      recipients    to_email
      headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      subject       subject
      sent_on       Time.now
      content_type  "text/html"    
    end
end