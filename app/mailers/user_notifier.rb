require 'mailer_deliver_alias'
require 'mail'
class UserNotifier < ActionMailer::Base

  layout "email_font"
  include EmailHelper
  helper EmailActionsHelper

  def user_activation(user, params, reply_email_config)
    begin 
      if (user.role_ids.include?(reply_email_config.account.roles.find_by_name("Account Administrator").id))
        call_location = "Agent Creation"
        SpamDetection::SignupRestrictedDomainValidation.perform_async({:account_id=>reply_email_config.account.id, :email=>user.email, :call_location=>call_location})
      end
    rescue Exception => e
      Rails.logger.info "SignupRestrictedDomainValidation failed #{reply_email_config.account.id} #{e.messsage}, #{e.backtrace}"
    end
    begin
      configure_email_config reply_email_config
      @activation_url = params[:activation_url] if params.has_key?(:activation_url)
      send_the_mail(user, params[:subject], params[:email_body], params[:reply_email], EmailNotification::USER_ACTIVATION)
    ensure
      remove_email_config
    end
  end

  def email_activation(email_id, params, reply_email_config)
    begin
      configure_email_config reply_email_config
      @activation_url = params[:activation_url] if params.has_key?(:activation_url)
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
      from: address.format,
      to: admin.email,
      subject: I18n.t('mailer_notifier_subject.admin_activation', app_name: AppConfig['app_name']),
      sent_on: Time.now
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
  
  def agent_invitation(user, params, reply_email_config)
    begin
      configure_email_config reply_email_config  
      send_the_mail(user, params[:subject], params[:email_body], params[:reply_email], EmailNotification::AGENT_INVITATION)
    ensure
      remove_email_config
    end
  end

  def custom_ssl_activation(account, portal_url, elb_name)
    headers = {
      from: AppConfig['from_email'],
      to: account.admin_email,
      subject: I18n.t('mailer_notifier_subject.custom_ssl_activation'),
      sent_on: Time.now
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
      :subject         => I18n.t('mailer_notifier_subject.notify_dkim_activation'),
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
      :subject         => I18n.t('mailer_notifier_subject.notify_dkim_activation'),
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
      :subject    => 'Dkim Failure Notification',
      :to         => 'diya.biju@freshworks.com',
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now,
      'Reply-to'       => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }
    @details = args
    mail(headers) do |part|
      part.text { render 'notify_dev_dkim_failure.text.plain.erb' }
      part.html { render 'notify_dev_dkim_failure.text.html.erb' }
    end.deliver
  end

  def notify_skill_import(args)
    @account = Account.current
    @attachment_files = args[:attachments] if args[:attachments].present?
    headers = {
      :subject    => t(:'flash.import.info19', :portal_url => @account.full_domain),
      :to         => User.current.email,
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now,
      "Reply-to"       => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    if args[:csv_data].present?
      attachments["skill_import.csv"] = {
        :mime_type => "text/csv",
        :content => args[:csv_data]
      }
    end unless @account.secure_attachments_enabled?

    @params = args
    mail(headers) do |part|
      part.text { render "notify_skill_import.text.plain.erb" }
      part.html { render "notify_skill_import.text.html.erb" }
    end.deliver
  end

  def notify_account_deletion(args)
    headers = {
      :subject    => "Account Deletion",
      :to         => "infosec@freshworks.com",
      :from       => AppConfig['from_email'],
      :sent_on    => Time.now,
      "Reply-to"       => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @details = args
    mail(headers) do |part|
      part.text { render "notify_account_deletion.text.plain.erb" }
      part.html { render "notify_account_deletion.text.html.erb" }
    end.deliver
  end

  def notify_customers_import(options={})
    begin
      # sending this email via account's primary email config so that if the customer wants this emails 
      # to be sent via custom mail server, simply switching the primary email config will do
      @account = options[:user].account
      email_config = @account.primary_email_config
      configure_email_config email_config
      @import_stopped = options[:import_stopped]
      import_subject_key = @import_stopped ? 'customer_import_stopped' : 'customer_import'
      @attachment_files = options[:attachments] if options[:attachments].present?

      @account_domain = @account.full_domain
      headers = {
        :subject                    => I18n.t("mailer_notifier_subject.#{import_subject_key}",
                                      import_type: I18n.t("search.#{options[:type]}", default: options[:type].capitalize),
                                      account_full_domain: @account_domain),
        :to                         => options[:user].email,
        :from                       => @account.default_friendly_email,
        :bcc                        => AppConfig['reports_email'],
        :sent_on                    => Time.now,
        :"Reply-to"                 => "#{@account.default_friendly_email}",
        :"Auto-Submitted"           => "auto-generated",
        :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }

      headers.merge!(make_header(nil, nil, @account.id, "Notify Customers Import"))
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

      if options[:file_path].present? && !@account.secure_attachments_enabled?
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
      subject: I18n.t('mailer_notifier_subject.notify_facebook_reauth'),
      to: account.admin_email,
      from: AppConfig['from_email'],
      sent_on: Time.now
    }
    headers.merge!(make_header(nil, nil, account.id, "Notify Facebook Reauth"))
    @facebook_url    = admin_social_facebook_streams_url(:host => account.host)
    @fb_page         = facebook_page
    @admin_name      = account.admin_first_name
    mail(headers) do |part|
      part.text { render "facebook.text.plain" }
      part.html { render "facebook.text.html" }
    end.deliver
  end

  def notify_webhook_failure(email_hash, account, triggering_rule, url)
    Time.zone = account.time_zone
    headers = {
      :subject       => I18n.t('mailer_notifier_subject.notify_webhook_failure'),
      :to            => email_hash[:group],
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    
    @other_emails = email_hash[:other]
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

  def notify_webhook_drop(email_hash, account)
    Time.zone = account.time_zone
    headers = {
      :subject       => I18n.t('mailer_notifier_subject.notify_webhook_drop'),
      :to            => email_hash[:group],
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    @other_emails = email_hash[:other]
    headers.merge!(make_header(nil, nil, account.id, "Notify Webhook Drop"))
    @solution_article_link = 'https://support.freshdesk.com/support/solutions/articles/217264-webhooks-faq'
    mail(headers) do |part|
      part.text { render "webhook_drop.text.plain" }
      part.html { render "webhook_drop.text.html" }
    end.deliver
  end

  def helpdesk_url_reminder(email_id, helpdesk_urls)
    headers = {
      :subject    => I18n.t('mailer_notifier_subject.helpdesk_url_reminder'),
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
      :subject    => I18n.t('mailer_notifier_subject.failure_transaction_notifier'),
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

  def push_contact_deleted_info(account, contact, deleted_by, deleted_at)
    headers = {
      :subject       => "Contact #{contact.id} deleted from account #{account.id}",
      :to            => AppConfig['reports_email'],
      :from          => AppConfig['from_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated",
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    @account = account
    @contact = contact
    @deleted_by = deleted_by
    @deleted_at = deleted_at

    headers.merge!(make_header(nil, nil, account.id, "Contact deleted info"))
    mail(headers) do |part|
      part.text { render "push_contact_deleted_info.text.plain" }
      part.html { render "push_contact_deleted_info.text.html" }
    end.deliver
  end

  def notify_proactive_outreach_import(options = {})
    @render_options = {}
    @account = options[:user].account
    email_config = @account.primary_email_config
    configure_email_config email_config
    @render_options[:import_success] = options[:import_success]
    import_subject_key = @render_options[:import_success] ? 'outreach_customer_import' : 'outreach_customer_import_failure'
    @attachment_files = options[:attachments] if options[:attachments].present?

    headers = {
      :subject => I18n.t("mailer_notifier_subject.#{import_subject_key}"),
      :to => options[:user].email,
      :from => @account.default_friendly_email,
      :bcc => AppConfig['reports_email'],
      :sent_on => Time.zone.now,
      :"Reply-to" => @account.default_friendly_email.to_s,
      :"Auto-Submitted" => 'auto-generated',
      :"X-Auto-Response-Suppress" => 'DR, RN, OOF, AutoReply'
    }

    headers.merge!(make_header(nil, nil, @account.id, 'Notify Customers Import'))
    headers["X-FD-Email-Category"] = email_config.category if email_config.category.present?
    @render_options.merge!({
      user: options[:user],
      type: options[:type],
      outreach_name: options[:outreach_name],
      success_count: options[:success_count],
      failed_count: options[:failed_count],
      attachment: options[:file_name],
      corrupted: options[:corrupted],
      wrong_csv: options[:wrong_csv]
    })

    if options[:file_path].present? && !@account.secure_attachments_enabled?
      attachments[options[:file_name]] = {
        mime_type: 'text/csv',
        content: File.read(options[:file_path], :mode => 'rb')
      }
    end

    mail(headers) do |part|
      part.text { render 'notify_proactive_outreach_import.text.plain' }
      part.html { render 'notify_proactive_outreach_import.text.html' }
    end.deliver
  ensure
    remove_email_config
  end

  def notify_email_rate_limit_exceeded(admin_emails)
    headers = {
      :subject => I18n.t('mailer_notifier_subject.email_rate_limit_exceeded', account_url: Account.current.full_domain),
      :to => admin_emails[:group],
      :from => AppConfig['from_email'],
      :sent_on => Time.now.in_time_zone,
      'Reply-to' => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }

    @other_emails = admin_emails[:other]

    mail(headers) do |part|
      part.text { render 'email_rate_limit_exceeded.text.plain' }
      part.html { render 'email_rate_limit_exceeded.text.html' }
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
