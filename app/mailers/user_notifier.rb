require 'mailer_deliver_alias'
require 'mail'
class UserNotifier < ActionMailer::Base

  layout "email_font"
  include EmailHelper
  def user_activation(user, params, reply_email_config)
    begin
      configure_email_config reply_email_config
      send_the_mail(user, params[:subject], params[:email_body], params[:reply_email], EmailNotification::USER_ACTIVATION)
    ensure
      remove_email_config
    end
  end

  def email_activation(email_id, params, reply_email_config)
    begin
      configure_email_config reply_email_config
      send_the_mail(email_id, params[:subject], params[:email_body], params[:reply_email], "Email Activation")
    ensure
      remove_email_config
    end
  end

  def password_reset_instructions(user, params, reply_email_config)
    begin
      configure_email_config reply_email_config  
      send_the_mail(user, params[:subject], params[:email_body], params[:reply_email], EmailNotification::PASSWORD_RESET)
    ensure
      remove_email_config
    end
  end
  
  def admin_activation(admin)
    # Safe way to include name with email address 
    address = Mail::Address.new AppConfig['from_email']
    # Should we dup or are we using the latest mail gem?
    # (latest mail gem does dup already)
    address.display_name = AppConfig['app_name'].dup

    headers = {
      :from           => address.format,
      :to             => admin.email,
      :subject        => "Activate your #{AppConfig['app_name']} account",
      :sent_on        => Time.now
    }
   headers.merge!(make_header(nil, nil, admin.account.id, "Admin Activation"))
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

    headers.merge!(make_header(nil, nil, account.id, "Custom SSL Activation"))
    @admin_name   = "#{account.admin_first_name} #{account.admin_last_name}"
    @portal_url   = portal_url
    @elb_name     = elb_name
    @account      = account

    mail(headers) do |part|
      part.text { render "custom_ssl_activation.text.plain" }
      part.html { render "custom_ssl_activation.text.html" }
    end.deliver
  end

  def notify_dkim_activation(account, dkim_details = {})
    Time.zone = account.time_zone
    @admin_name = "#{account.admin_first_name} #{account.admin_last_name}"
    headers = {
      :subject         => "DKIM signatures activation email",
      :to              => account.admin_email,
      :from            => AppConfig['from_email'],
      :sent_on         => Time.now,
      "Reply-to"       => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @dkim_details = dkim_details
    mail(headers) do |part|
      part.text { render "notify_dkim_activation.text.plain.erb" }
      part.html { render "notify_dkim_activation.text.html.erb" }
    end.deliver
  end

  def notify_dkim_failure(account, dkim_details = {})
    Time.zone = account.time_zone
    @admin_name = "#{account.admin_first_name} #{account.admin_last_name}"
    headers = {
      :subject         => "DKIM signatures activation email",
      :to              => account.admin_email,
      :from            => AppConfig['from_email'],
      :sent_on         => Time.now,
      "Reply-to"       => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @dkim_details = dkim_details
    mail(headers) do |part|
      part.text { render "notify_dkim_failure.text.plain.erb" }
      part.html { render "notify_dkim_failure.text.html.erb" }
    end.deliver
  end
  
  def notify_dev_dkim_failure(args)
    headers = {
      :subject    => "Dkim Failure Notification",
      :to         => "ramkumar@freshdesk.com",
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now,
      "Reply-to"       => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @details = args
    mail(headers) do |part|
      part.text { render "notify_dev_dkim_failure.text.plain.erb" }
      part.html { render "notify_dev_dkim_failure.text.html.erb" }
    end.deliver
  end

  def notify_customers_import(options={})
    begin
      # sending this email via account's primary email config so that if the customer wants this emails 
      # to be sent via custom mail server, simply switching the primary email config will do
      email_config = options[:user].account.primary_email_config
      configure_email_config email_config
      headers = {
        :subject                    => "#{options[:type].capitalize} Import for #{options[:user].account.full_domain}",
        :to                         => options[:user].email,
        :from                       => options[:user].account.default_friendly_email,
        :bcc                        => AppConfig['reports_email'],
        :sent_on                    => Time.now,
        :"Reply-to"                 => "#{options[:user].account.default_friendly_email}", 
        :"Auto-Submitted"           => "auto-generated", 
        :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }

      headers.merge!(make_header(nil, nil, options[:user].account.id, "Notify Customers Import"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      @user = options[:user]
      @type = options[:type]
      @created = options[:created_count]
      @updated = options[:updated_count]
      @failed = options[:failed_count]
      @attachment = options[:file_name]
      @import_success = options[:import_success]
      @corrupted = options[:corrupted]
      @wrong_csv = options[:wrong_csv]

      unless options[:file_path].nil?
        attachments[options[:file_name]] = {
          :mime_type => "text/csv",
          :content => File.read(options[:file_path], :mode => "rb")
        }
      end

      mail(headers) do |part|
        part.text { render "notify_customers_import.text.plain" }
        part.html { render "notify_customers_import.text.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def notify_facebook_reauth(facebook_page)
    account          = Account.current
    headers = {
      :subject       => "Need Attention, Facebook app should be reauthorized",
      :to            => account.admin_email,
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now
    }
    headers.merge!(make_header(nil, nil, account.id, "Notify Facebook Reauth"))
    @facebook_url    = social_facebook_index_url(:host => account.host)
    @fb_page         = facebook_page
    @admin_name      = account.admin_first_name
    mail(headers) do |part|
      part.text { render "facebook.text.plain" }
      part.html { render "facebook.text.html" }
    end.deliver
  end
  
  def notify_webhook_failure(account, to_email, triggering_rule, url)
    Time.zone = account.time_zone
    headers = {
      :subject       => "Please recheck the webhook settings in your account",
      :to            => to_email,
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    
    headers.merge!(make_header(nil, nil, account.id, "Notify Webhook Failure"))
    @automation_type = triggering_rule[:type].to_s
    @automation_name = triggering_rule[:name].to_s
    @automation_link = triggering_rule[:path].to_s
    @webhook_url = url
    
    mail(headers) do |part|
      part.text { render "webhook_failure.text.plain" }
      part.html { render "webhook_failure.text.html" }
    end.deliver
  end

  def notify_webhook_drop(account, to_email)
    Time.zone = account.time_zone
    headers = {
      :subject       => "Webhook dropped",
      :to            => to_email,
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    headers.merge!(make_header(nil, nil, account.id, "Notify Webhook Drop"))
    mail(headers) do |part|
      part.text { render "webhook_drop.text.plain" }
      part.html { render "webhook_drop.text.html" }
    end.deliver
  end

  def helpdesk_url_reminder(email_id, helpdesk_urls)
    headers = {
      :subject    => "Your Freshdesk Portal Information",
      :to         => email_id,
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now
    }

    account_id = -1

    account_id = Account.current.id if Account.current

    headers.merge!(make_header(nil, nil, account_id, "Helpdesk Url Reminder"))
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

    account_id = -1

    account_id = Account.current.id if Account.current

    headers.merge!(make_header(nil, nil, account_id, "One Time Password"))
    mail(headers).deliver
  end

  def failure_transaction_notifier(email_id, content = "")
    headers = {
      :subject    => "Payment failed for auto recharge of day passes",
      :to         => email_id,
      :from       => AppConfig["billing_email"],
      :sent_on    => Time.now
    }

    account_id = -1

    account_id = Account.current.id if Account.current

    headers.merge!(make_header(nil, nil, account_id, "Failure Transaction Notifier"))
    @content = content
    mail(headers) do |part|
      part.text { render "failure_transaction_notifier.text.plain" }
      part.html { render "failure_transaction_notifier.text.html" }
    end.deliver
  end
  
  def notify_special_pricing(account)
    headers = {
      :from       => AppConfig['from_email'],
      :to         => "ramkumar@freshdesk.com",
      :subject    => "Special pricing request",
      :sent_on    => Time.now
    }
    @account = account
    
    mail(headers) do |part|
      part.text { render "notify_special_pricing.text.plain" }
      part.html { render "notify_special_pricing.text.html" }
    end.deliver
  end

  private

    def send_the_mail(user_or_email, subject, email_body, reply_email =nil, type)
      email_config = Thread.current[:email_config]
      headers = {
        :to => user_or_email.email, 
        :from => reply_email || user_or_email.account.default_friendly_email,
        :subject => subject,
        :sent_on => Time.zone.now,
        :reply_to => "#{reply_email || user_or_email.account.default_friendly_email}",
        :"Auto-Submitted" => "auto-generated", 
        :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }
      headers.merge!(make_header(nil, nil, user_or_email.account.id, type))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      mail(headers) do |part|
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
