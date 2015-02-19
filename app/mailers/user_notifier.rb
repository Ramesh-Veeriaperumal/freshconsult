require 'mailer_deliver_alias'
class UserNotifier < ActionMailer::Base

  layout "email_font"

  def user_activation(user, params, reply_email_config)
    ActionMailer::Base.set_mailbox reply_email_config.smtp_mailbox
    send_the_mail(user, params[:subject], params[:email_body], params[:reply_email])
  end

  def email_activation(email_id, params, reply_email_config)
    ActionMailer::Base.set_mailbox reply_email_config.smtp_mailbox
    send_the_mail(email_id, params[:subject], params[:email_body], params[:reply_email])
  end

  def password_reset_instructions(user, params, reply_email_config)  
    ActionMailer::Base.set_mailbox reply_email_config.smtp_mailbox  
    send_the_mail(user, params[:subject], params[:email_body], params[:reply_email])
  end
  
  def admin_activation(admin)
    headers = {
      :from           => AppConfig['from_email'],
      :to             => admin.email,
      :subject        => "#{AppConfig['app_name']} Account Activation",
      :sent_on        => Time.now
    }
    @admin          = admin
    @activation_url = register_url( 
      :activation_code => admin.perishable_token, 
      :host => admin.account.host , 
      :protocol => admin.url_protocol 
    )
    @account = admin.account

    mail(headers) do |part|
      part.text { render "admin_activation.text.plain" }
      part.html { render "admin_activation.text.html" }
    end.deliver

  end
  alias :account_admin_activation :admin_activation 

  def custom_ssl_activation(account, portal_url, elb_name)
    headers = {
      :from       => AppConfig['from_email'],
      :to         => account.admin_email,
      :subject    => "Custom SSL Activated",
      :sent_on    => Time.now
    }

    @admin_name   = "#{account.admin_first_name} #{account.admin_last_name}"
    @portal_url   = portal_url
    @elb_name     = elb_name
    @account      = account

    mail(headers) do |part|
      part.text { render "custom_ssl_activation.text.plain" }
      part.html { render "custom_ssl_activation.text.html" }
    end.deliver
  end

  def notify_contacts_import(user)
    headers = {
      :subject                    => "Contacts Import for #{user.account.full_domain}",
      :to                         => user.email,
      :from                       => user.account.default_friendly_email,
      :sent_on                    => Time.now,
      :"Reply-to"                 => "#{user.account.default_friendly_email}", 
      :"Auto-Submitted"           => "auto-generated", 
      :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    @user = user
    @account = user.account

    mail(headers) do |part|
      part.text { render "notify_contacts_import.text.plain" }
      part.html { render "notify_contacts_import.text.html" }
    end.deliver
  end

  def notify_facebook_reauth(account,facebook_page)
    headers = {
      :subject       => "Need Attention, Facebook app should be reauthorized",
      :to            => account.admin_email,
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now
    }
    @facebook_url    = social_facebook_index_url(:host => account.host)
    @fb_page         = facebook_page
    @admin_name      = account.admin_first_name
    @account         = account
    mail(headers) do |part|
      part.text { render "facebook.text.plain" }
      part.html { render "facebook.text.html" }
    end.deliver
  end

  def helpdesk_url_reminder(email_id, helpdesk_urls)
    headers = {
      :subject    => "Your Freshdesk Portal Information",
      :to         => email_id,
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now
    }
    @helpdesk_urls = helpdesk_urls
    mail(headers) do |part|
      part.html { render "helpdesk_url_reminder", :formats => [:html] }
    end.deliver   
  end

  def one_time_password(email_id,text = "")
    headers = {
      :subject    => "One time password instructions to login",
      :to         => email_id,
      :from       => "admin@freshdesk.com",
      :sent_on    => Time.now,
      :body       => text
    }
    mail(headers).deliver
  end

  private

    def send_the_mail(user_or_email, subject, email_body, reply_email =nil)
      mail(:to => user_or_email.email, 
        :from => reply_email || user_or_email.account.default_friendly_email,
        :subject => subject,
        :sent_on => Time.zone.now,
        :reply_to => "#{reply_email || user_or_email.account.default_friendly_email}",
        :"Auto-Submitted" => "auto-generated", 
        :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply") do |part|
          part.text do
            @body = Helpdesk::HTMLSanitizer.plain(email_body)
            render("user_notification_mail.text.plain")
          end

          part.html do
            @body = email_body
            @account = user_or_email.account
            render("user_notification_mail.text.html")
          end
      end.deliver
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
