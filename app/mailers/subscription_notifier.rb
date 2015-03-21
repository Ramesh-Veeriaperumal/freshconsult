class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper

  layout "email_font"
  
  def sub_error(options={})
    setup_email("kiran@freshdesk.com", "Error in Subscription module for #{options[:custom_message]}")
    @message = options[:error_msg], @full_domain = options[:full_domain]
    mail(@headers) do |part|
      part.html { render "sub_error", :formats => [:html] }
    end.deliver
  end
  
  def welcome(account)
    setup_email(account.admin_email, "Welcome to #{AppConfig['app_name']}!","vijay@freshdesk.com")
    @account = account, @host = account.host
    mail(@headers) do |part|
      part.html { render "welcome", :formats => [:html] }
    end.deliver
  end
  
  def trial_expiring(user, subscription, trial_days = nil)
    setup_email(user,"Your Freshdesk trial expires in #{trial_days}")
    setup_bcc("kiran@freshdesk.com")
    @user = user, @subscription = subscription, @trial_days = trial_days

    mail(@headers) do |part|
      part.html { render "trial_expiring", :formats => [:html] }
    end.deliver
  end
  
  def charge_receipt(subscription_payment)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @subscription = subscription_payment.subscription
    @amount = subscription_payment.amount, @subscription_payment = subscription_payment 
    mail(@headers) do |part|
      part.html { render "charge_receipt", :formats => [:html]}
    end.deliver
  end
  
  def day_pass_receipt(quantity, subscription_payment)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @units = quantity, @subscription_payment = subscription_payment, 
    @subscription = subscription_payment.subscription
    mail(@headers) do |part|
      part.html { render "day_pass_receipt", :formats => [:html]}
    end.deliver
  end
  
  def misc_receipt(subscription_payment,description)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @subscription = subscription_payment.subscription, 
    @subscription_payment = subscription_payment, @description = description
    mail(@headers) do |part|
      part.html { render "misc_receipt", :formats => [:html]}
    end.deliver
  end
  
  def charge_failure(subscription)
    setup_email(subscription.invoice_emails, "Your #{AppConfig['app_name']} renewal failed")
    @bcc = AppConfig['from_email']
    @subscription = subscription
    mail(@headers) do |part|
      part.html { render "charge_failure", :formats => [:html]}
    end.deliver   
  end
  
  def account_deleted(account, feedback)
    setup_email(AppConfig['from_email'], "#{account.full_domain} is deleted")
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
      :subject => "Freshdesk :: Spam watcher",
      :sent_on => Time.now
    }
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
      :subject     =>  "Freshdesk :: Spam watcher",
      :sent_on     =>  Time.now
    }
    @account = account
    mail(@headers) do |part|
      part.html { render "admin_spam_watcher_blocked", :formats => [:html] }
    end.deliver
  end

  def admin_spam_watcher_blocked(account)
    @headers = {
      :from        =>  AppConfig['from_email'],
      :to          =>  account.admin_email,
      :subject     =>  "Freshdesk :: Spam watcher",
      :sent_on     =>  Time.now
    }
    @account = account
    mail(@headers) do |part|
      part.html { render "admin_spam_watcher_blocked.html"}
    end.deliver
  end

  def subscription_downgraded(subscription, old_subscription)
    setup_email(AppConfig['from_email'], "#{subscription.account.full_domain} downgraded")
    @subscription = subscription
    @old_subscription = old_subscription
    mail(@headers) do |part|
      part.html { render "subscription_downgraded", :formats => [:html]}
    end.deliver
  end

  private
    def setup_email(to, subject, from = AppConfig['billing_email'])
      @headers = {
        :subject  => subject,
        :to       => to.respond_to?(:email) ? to.email : to,
        :from     => from.respond_to?(:email) ? from.email : from , 
        :sent_on  => Time.now
      }
    end

    def setup_bcc(bcc)
      @headers[:bcc] = bcc || AppConfig['sub_bcc_email'][Rails.env] if Rails.env.production?
    end
  
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
  
end
