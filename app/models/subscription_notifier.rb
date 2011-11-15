class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper
  
  def setup_email(to, subject, from = AppConfig['billing_email'])
    @sent_on = Time.now
    @subject = subject
    @recipients = to.respond_to?(:email) ? to.email : to
    @from = from.respond_to?(:email) ? from.email : from   
  end
  
  def sub_error(options={})
    setup_email("kiran@freshdesk.com", "Error in Subscription module for #{options[:custom_message]}")
    @body = {:message => options[:error_msg], :full_domain => options[:full_domain]}
  end
  
  def setup_bcc
     @bcc = AppConfig['sub_bcc_email'][RAILS_ENV]
  end
  
  def welcome(account)
    setup_email(account.account_admin, "Welcome to #{AppConfig['app_name']}!","vijay@freshdesk.com")
    @body = { :account => account, :host => account.host }
    @content_type = "text/html"
  end
  
  def trial_expiring(user, subscription, trial_days = nil)
    setup_email(user,"Your Freshdesk trial expires in #{trial_days}")
    @bcc = "kiran@freshdesk.com"
    @body = { :user => user, :subscription => subscription, :trial_days => trial_days }
    @content_type = "text/html"
  end
  
  def charge_receipt(subscription_payment)
    setup_email(subscription_payment.subscription.account.account_admin, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @body = { :subscription => subscription_payment.subscription, :amount => subscription_payment.amount }
  end
  
  def setup_receipt(subscription_payment)
    setup_email(subscription_payment.subscription.account.account_admin, "Your #{AppConfig['app_name']} invoice")
    @body = { :subscription => subscription_payment.subscription, :amount => subscription_payment.amount }
  end
  
  def misc_receipt(subscription_payment)
    setup_email(subscription_payment.subscription.account.account_admin, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @body = { :subscription => subscription_payment.subscription, :amount => subscription_payment.amount }
  end
  
  def charge_failure(subscription)
    setup_email(subscription.account.account_admin, "Your #{AppConfig['app_name']} renewal failed")
    @bcc = AppConfig['from_email']
    @body = { :subscription => subscription }    
  end
  
  def plan_changed(subscription)
    setup_email(subscription.account.account_admin, "Your #{AppConfig['app_name']} plan has been changed")
    @body = { :subscription => subscription }    
  end
  
  def account_deleted(account)
    setup_email(AppConfig['from_email'], "#{account.full_domain} is deleted")
    @body = { :account => account }    
    @content_type = "text/html"
  end
  
  def password_reset(reset)
    setup_email(reset.user, 'Password Reset Request')
    @body = { :reset => reset }
  end
end
