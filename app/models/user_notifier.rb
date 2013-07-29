class UserNotifier < ActionMailer::Base
  def user_activation(user, params)
    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end
  
  def password_reset_instructions(user, params)
    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end
  
  def send_the_mail(user, email_body, reply_email =nil)
    from          reply_email || user.account.default_friendly_email
    recipients    user.email
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("user_notification_mail.text.plain.erb", :body => Helpdesk::HTMLSanitizer.plain(email_body))
      end

      alt.part "text/html" do |html|
        html.body   render_message("user_notification_mail.text.html.erb", :body => email_body)
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
          :activation_url => register_url(:activation_code => admin.perishable_token, :host => admin.account.host , :protocol => admin.url_protocol ))
      end
    end
  end
  alias :account_admin_activation :admin_activation 

  def custom_ssl_activation(account, portal_url, elb_name)
    from          AppConfig['from_email']
    recipients    account.admin_email
    subject       "Custom SSL Activated"
    body          :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", :portal_url => portal_url, :elb_name => elb_name
    sent_on       Time.now

    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("custom_ssl_activation.text.plain.erb", :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", 
                                    :portal_url => portal_url, :elb_name => elb_name)
      end

      alt.part "text/html" do |html|
        html.body   render_message("custom_ssl_activation.text.html.erb", :admin_name => "#{account.admin_first_name} #{account.admin_last_name}", 
                                    :portal_url => portal_url, :elb_name => elb_name)
      end
    end

  end

  def notify_contacts_import(user)
    subject       "Contacts Import for #{user.account.full_domain}"
    recipients    user.email
    from          user.account.default_friendly_email
    body          :user => user
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_contacts_import.text.plain.erb", :user => user)
      end

      alt.part "text/html" do |html|
        html.body   render_message("notify_contacts_import.text.html.erb", :user => user)
      end
    end

  end

end
