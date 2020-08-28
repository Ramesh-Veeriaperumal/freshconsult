class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper
  include Cache::Memcache::SubscriptionPlan
  include EmailHelper

  layout "email_font"
  
  def sub_error(options={})
    account_id = -1

    account_id = Account.find_by_full_domain(options[:full_domain]).id if(options[:full_domain] && Account.find_by_full_domain(options[:full_domain]))
    setup_email("kiran@freshdesk.com", "Error in Subscription module for #{options[:custom_message]}", account_id, "Subscription Error")
    @message = options[:error_msg]
    @full_domain = options[:full_domain]
    mail(@headers) do |part|
      part.html { render "sub_error", :formats => [:html] }
    end.deliver
  end
  
  def welcome(account)
    setup_email(account.admin_email, "Welcome to #{AppConfig['app_name']}!","vijay@freshdesk.com", account.id, "Welcome")
    @account = account
    @host = account.host
    mail(@headers) do |part|
      part.html { render "welcome", :formats => [:html] }
    end.deliver
  end
  
  def trial_expiring(user, subscription, trial_days = nil)
    setup_email(user,"Your Freshdesk trial expires in #{trial_days}", user.account_id, "Trial Expiring")
    setup_bcc("kiran@freshdesk.com")
    @user = user
    @subscription = subscription
    @trial_days = trial_days

    mail(@headers) do |part|
      part.html { render "trial_expiring", :formats => [:html] }
    end.deliver
  end
  
  def charge_receipt(subscription_payment)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice", subscription_payment.account_id, "Charge Receipt")
    setup_bcc
    @subscription = subscription_payment.subscription
    @amount = subscription_payment.amount
    @subscription_payment = subscription_payment 
    mail(@headers) do |part|
      part.html { render "charge_receipt", :formats => [:html]}
    end.deliver
  end
  
  def day_pass_receipt(quantity, subscription_payment)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice", subscription_payment.account_id, "Day Pass Receipt")
    setup_bcc
    @units = quantity
    @subscription_payment = subscription_payment 
    @subscription = subscription_payment.subscription
    mail(@headers) do |part|
      part.html { render "day_pass_receipt", :formats => [:html]}
    end.deliver
  end
  
  def misc_receipt(subscription_payment,description)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice", subscription_payment.account_id, "Misc Receipt")
    setup_bcc
    @subscription = subscription_payment.subscription
    @subscription_payment = subscription_payment
    @description = description
    mail(@headers) do |part|
      part.html { render "misc_receipt", :formats => [:html]}
    end.deliver
  end
  
  def charge_failure(subscription)
    setup_email(subscription.invoice_emails, "Your #{AppConfig['app_name']} renewal failed", subscription.account_id, "Charge Failure")
    @bcc = AppConfig['from_email']
    @subscription = subscription
    mail(@headers) do |part|
      part.html { render "charge_failure", :formats => [:html]}
    end.deliver   
  end
  
  def account_deleted(account, feedback)
    setup_email(AppConfig['cs_email'], "#{account.full_domain} is deleted", account.id, "Account Deleted")
    @account = account 
    @reason  = feedback
    mail(@headers) do |part|
      part.html { render "account_deleted", :formats => [:html]}
    end.deliver
  end

  def admin_spam_watcher(account, deleted_users,spam_watcher_redis=nil)
    @headers = {
      :from    => AppConfig['from_email'],
      :to      => account.admin_email,
      :subject => I18n.t('mailer_notifier_subject.spam_watcher'),
      :sent_on => Time.now
    }
    @headers.merge!(make_header(nil, nil, account.id, "Admin Spam Watcher"))
    @account = account 
    @deleted_users = deleted_users
    @spam_watcher_redis = spam_watcher_redis
    mail(@headers) do |part|
      part.html { render "admin_spam_watcher", :formats => [:html]}
    end.deliver
  end

  def admin_spam_watcher_blocked(account)
    @headers = {
      :from        =>  AppConfig['from_email'],
      :to          =>  account.admin_email,
      :subject     =>  I18n.t('mailer_notifier_subject.spam_watcher'),
      :sent_on     =>  Time.now
    }
    @headers.merge!(make_header(nil, nil, account.id, "Admin Spam Watcher Blocked"))
    @account = account
    mail(@headers) do |part|
      part.html { render "admin_spam_watcher_blocked", :formats => [:html] }
    end.deliver
  end

  def subscription_downgraded(subscription, old_subscription, requested_subscription, from_email)
    setup_email(AppConfig['cs_email'], "Downgrade request from #{subscription.account.full_domain}", from_email, subscription.account_id, 'Subscription Downgraded')
    @old_subscription = downgrade_notification_fields(old_subscription)
    @current_subscription = if requested_subscription.present?
                              downgrade_notification_fields(requested_subscription)
                            else
                              downgrade_notification_fields(subscription_info(subscription))
                            end
    @current_subscription.merge!({ admin_email: subscription.admin_email, account_id: subscription.account_id,
                                   account_full_domain: subscription.account.full_domain, currency_name: subscription.currency.name })
    mail(@headers) do |part|
      part.html { render "subscription_downgraded", :formats => [:html]}
    end.deliver
  end

  def salesforce_failures(account, caller_details)
    headers = {
      :subject    => "Salesforce account not found - #{account.id}",
      :to         => "support@signupreports.freshdesk.com",
      :from       => 'admin@freshdesk.com',
      :sent_on    => Time.now
    }
    headers.merge!(make_header(nil, nil, account.id, "Salesforce Failures"))
    @account = account
    @caller_details = caller_details
    mail(headers) do |part|
      part.html { render "salesforce_details", :formats => [:html] }
    end.deliver
  end

  def account_cancellation_requested(feedback, current_user)
    period = { 1 => "Monthly", 3 => "Quarterly", 6 => "Half Yearly", 12 => "Annual" }
    @account = Account.current
    from_email = current_user.present? ? current_user.email : @account.admin_email
    setup_email(AppConfig['cs_email'], "Cancellation request from #{Account.current.full_domain}.", from_email, Account.current.id, 'Cancellation Request')
    customer_details = @account.subscription.billing.retrieve_subscription(@account.id)
    @billing_start_date = Time.zone.at(customer_details.subscription.current_term_start).to_date.to_s(:db)
    @reason  = feedback
    @billing_period = period[@account.subscription.renewal_period]
    @freshops_account_url = freshops_account_url(Account.current)
    @field_technicians = @account.subscription.additional_info.present? ? @account.subscription.additional_info[:field_agent_limit] : nil
    mail(@headers) do |part|
      part.html { render "account_cancellation_requested", :formats => [:html]}
    end.deliver
  end

  def admin_account_cancelled(account_admins_email_list)
    setup_email(account_admins_email_list[:group],
                I18n.t('mailer_notifier_subject.account_cancelled', account_domain: Account.current.full_domain),
                AppConfig['from_email'],
                Account.current.id,
                'Account Cancelled')
    @account = Account.current
    @support_email = AppConfig['from_email']
    @other_emails = account_admins_email_list[:other]
    mail(@headers) do |part|
      part.html { render "admin_account_cancelled", :formats => [:html]}
    end.deliver
  end

  private
    def setup_email(to, subject, from = AppConfig['billing_email'], account_id, n_type)
      @headers = {
        :subject  => subject,
        :to       => to.respond_to?(:email) ? to.email : to,
        :from     => from.respond_to?(:email) ? from.email : from ,
        :sent_on  => Time.now
      }

      @headers.merge!(make_header(nil, nil, account_id, n_type))
    end

    def setup_bcc(bcc)
      @headers[:bcc] = bcc || AppConfig['sub_bcc_email'][Rails.env] if Rails.env.production?
    end

    def subscription_info(subscription)
      subscription_attributes =
        Subscription::SUBSCRIPTION_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = subscription.safe_send(v); h }
      subscription_attributes.merge!(next_renewal_at: subscription.next_renewal_at.to_s(:db))
    end

    def downgrade_notification_fields(subscription)
      subscription[:plan_name] = SubscriptionPlan.subscription_plans_from_cache.find { |plan| plan.id == subscription[:subscription_plan_id] }.name
      subscription
    end
  
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
  
end
