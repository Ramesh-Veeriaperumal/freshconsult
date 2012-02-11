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
  
  def google_contacts_import_email(options)
    @last_stats = options[:status]
    puts "@last_stats #{@last_stats.inspect}"
    set_default_mail_options options[:email], "Successfully imported Google contacts for #{options[:domain]}"
    body          (options)
  end

  def google_contacts_import_error_email(options)
    set_default_mail_options options[:email], "Error in importing Google contacts for #{options[:domain]}"
    body          (options)
  end

  private
    def set_default_mail_options(to_email, subject)
      from          "support@freshdesk.com"
      recipients    to_email
      subject       subject
      sent_on       Time.now
      content_type  "text/html"    
    end
end