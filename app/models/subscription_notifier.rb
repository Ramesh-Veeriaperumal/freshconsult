class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper

  layout "email_font"
  
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
    @bcc = AppConfig['sub_bcc_email'][RAILS_ENV] if Rails.env.production?
  end
  
  def welcome(account)
    setup_email(account.admin_email, "Welcome to #{AppConfig['app_name']}!","vijay@freshdesk.com")
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
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @body = { :subscription => subscription_payment.subscription, :amount => subscription_payment.amount, :subscription_payment => subscription_payment }
    @content_type = "text/html"
  end
  
  def day_pass_receipt(quantity, subscription_payment)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @body = { :units => quantity, :subscription_payment => subscription_payment, :subscription => subscription_payment.subscription }
    @content_type = "text/html"
  end
  
  def misc_receipt(subscription_payment,description)
    setup_email(subscription_payment.subscription.invoice_emails, "Your #{AppConfig['app_name']} invoice")
    setup_bcc
    @body = { :subscription => subscription_payment.subscription, :subscription_payment => subscription_payment, :description => description }
    @content_type = "text/html"
  end
  
  def charge_failure(subscription)
    setup_email(subscription.invoice_emails, "Your #{AppConfig['app_name']} renewal failed")
    @bcc = AppConfig['from_email']
    @body = { :subscription => subscription }    
    @content_type = "text/html"
  end
  
   def account_deleted(account)
    setup_email(AppConfig['from_email'], "#{account.full_domain} is deleted")
    @body = { :account => account }    
    @content_type = "text/html"
  end

  def admin_spam_watcher(account, deleted_users)
    from  AppConfig['from_email']
    recipients account.admin_email
    subject "Freshdesk :: Spam watcher"
    sent_on Time.now
    body(:account => account, 
          :deleted_users => deleted_users)
    content_type  "text/html"
  end

  def subscription_downgraded(subscription, old_subscription)
    setup_email(AppConfig['from_email'], "#{subscription.account.full_domain} downgraded")
    @body = { :subscription => subscription, :old_subscription => old_subscription }
    @content_type = "text/html"
  end 
  
end
