class Admin::DataImportMailer < ActionMailer::Base

  layout "email_font"
  
 def import_email(options={})
    headers = {
      :to      => options[:email],
      :from    => AppConfig['from_email'],
      :subject => "Data Import for #{options[:domain]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    mail(headers) do |part|
      part.html { render "import_email", :formats => [:html] }
    end.deliver
  end 
  
   def import_error_email(options={})
    headers = {
      :to      => options[:user][:email],
      :from    => AppConfig['from_email'],
      :subject => "Data Import for #{options[:domain]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @user = options[:user][:name]
    mail(headers) do |part|
      part.html { render "import_error_email", :formats => [:html] }
    end.deliver
  end 

  def import_format_error_email(options={}) 
    headers = {
      :to        => options[:user][:email],
      :from      => AppConfig['from_email'],
      :subject   => "Data Import for #{options[:domain]}",
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @user = options[:user][:name]
    mail(headers) do |part|
      part.html { render "import_format_error_email", :formats => [:html] }
    end.deliver
  end

  def import_summary(options={})
    headers = {
      :to        => options[:user][:email],
      :from      => AppConfig['from_email'],
      :subject   => "Import from Zendesk successful",
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @user = options[:user][:name]
    mail(headers) do |part|
      part.html { render "import_summary", :formats => [:html] }
    end.deliver
  end 
  
  def google_contacts_import_email(options)
    headers = {
      :from    => AppConfig['from_email'],
      :to      => options[:email],
      :subject => "Successfully imported Google contacts for #{options[:domain]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @last_stats = options[:status]
    mail(headers) do |part|
      part.html { render "google_contacts_import_email", :formats => [:html] }
    end.deliver
  end

  def google_contacts_import_error_email(options)
    headers = {
      :from    => AppConfig['from_email'],
      :to      => options[:email],
      :subject => "Error in importing Google contacts for #{options[:domain]}",
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    mail(headers) do |part|
      part.html { render "google_contacts_import_error_email", :formats => [:html] }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end