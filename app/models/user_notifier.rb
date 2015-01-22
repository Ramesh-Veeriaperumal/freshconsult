class UserNotifier < ActionMailer::Base
  
  layout "email_font"

  def user_activation(user, params, reply_email_config)
    self.class.set_mailbox reply_email_config.smtp_mailbox

    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end

  def email_activation(email_id, params, reply_email_config)
    self.class.set_mailbox reply_email_config.smtp_mailbox

    subject     params[:subject]
    send_the_mail(email_id, params[:email_body], params[:reply_email])
  end
  
  def password_reset_instructions(user, params, reply_email_config)
    self.class.set_mailbox reply_email_config.smtp_mailbox
    
    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end
  
  def send_the_mail(user_or_email, email_body, reply_email =nil)
    from          reply_email || user_or_email.account.default_friendly_email
    recipients    user_or_email.email
    sent_on       Time.now
    headers       "Reply-to" => "#{reply_email || user_or_email.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("user_notification_mail.text.plain.erb", :body => Helpdesk::HTMLSanitizer.plain(email_body))
      end

      alt.part "text/html" do |html|
        html.body   render_message("user_notification_mail.text.html.erb", :body => email_body, :account => user_or_email.account)
      end
    end
    
  end
  
  def admin_activation(admin)
    from  AppConfig['from_email'] 
    recipients admin.email
    subject "#{AppConfig['app_name']} Account Activation"
    sent_on Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("admin_activation.text.plain.erb", :admin => admin, 
          :activation_url => register_url(:activation_code => admin.perishable_token, :host => admin.account.host , :protocol => admin.url_protocol ))
      end

      alt.part "text/html" do |html|
        html.body   render_message("admin_activation.text.html.erb", :admin => admin, 
          :activation_url => register_url(:activation_code => admin.perishable_token, :host => admin.account.host , :protocol => admin.url_protocol), :account => admin.account )
      end
    end
  end
  alias :account_admin_activation :admin_activation 

  def custom_ssl_activation(account, portal_url, elb_name)
    from          AppConfig['from_email']
    recipients    account.admin_email
    subject       "Custom SSL Activated"
    # body          :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", :portal_url => portal_url, :elb_name => elb_name
    sent_on       Time.now

    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("custom_ssl_activation.text.plain.erb", :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", 
                                    :portal_url => portal_url, :elb_name => elb_name)
      end

      alt.part "text/html" do |html|
        html.body   render_message("custom_ssl_activation.text.html.erb", :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", 
                                    :portal_url => portal_url, :elb_name => elb_name, :account => account)
      end
    end

  end

  def notify_customers_import(options={})
    subject       "#{options[:type]} Import for #{options[:user].account.full_domain}"
    recipients    options[:user].email
    from          options[:user].account.default_friendly_email
    # body          :user => user
    sent_on       Time.now
    headers       "Reply-to" => "#{options[:user].account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_customers_import.text.plain.erb", :user => options[:user], 
                :type => options[:type], 
                :success_count => options[:success_count], 
                :failed_count => options[:failed_count],
                :import_success => options[:import_success],
                :attachment => options[:file_name])
      end

      alt.part "text/html" do |html|
        html.body   render_message("notify_customers_import.text.html.erb", :user => options[:user], 
                :type => options[:type], 
                :success_count => options[:success_count], 
                :failed_count => options[:failed_count],
                :import_success => options[:import_success],
                :attachment => options[:file_name])
      end
    end

    unless options[:file_path].nil?
      attachment  :content_type => "text/csv",
                    :body => File.read(options[:file_path], :mode => "rb"),
                    :filename => options[:file_name]
    end
  end

  def notify_facebook_reauth(account,facebook_page)
    subject "Need Attention, Facebook app should be reauthorized"
    recipients account.admin_email  
    from AppConfig['from_email']
    sent_on       Time.now
    content_type  "multipart/mixed"
    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body   render_message("facebook.text.plain.erb",
                                    :facebook_url => social_facebook_index_url(:host => account.host), 
                                    :fb_page => facebook_page, 
                                    :admin_name=> account.admin_first_name)
      end
      alt.part "text/html" do |html|
        html.body   render_message("facebook.text.html.erb",
                                    :facebook_url => social_facebook_index_url(:host => account.host), 
                                    :fb_page => facebook_page, :account => account,
                                    :admin_name=> account.admin_first_name)
      end
    end
  end

  def helpdesk_url_reminder(email_id, helpdesk_urls)
    subject       "Your Freshdesk Portal Information"
    recipients    email_id
    from          AppConfig['from_email'] 
    body          :helpdesk_urls => helpdesk_urls
    sent_on       Time.now
    content_type  "text/html"     
  end

  def one_time_password(email_id,text = "")
    subject       "One time password instructions to login"
    recipients    email_id
    from          "admin@freshdesk.com"
    sent_on       Time.now
    content_type  "text/html"
    body           text
  end

end
