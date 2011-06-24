class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper
  
  def setup_email(to, subject, from = AppConfig['from_email'])
    @sent_on = Time.now
    @subject = subject
    @recipients = to.respond_to?(:email) ? to.email : to
    @from = from.respond_to?(:email) ? from.email : from
  end
  
  def setup_bcc
     @bcc = AppConfig['sub_bcc_email'][RAILS_ENV]
  end
  
  def welcome(account)
    setup_email(account.account_admin, "Welcome to #{AppConfig['app_name']}!")
    @body = { :account => account, :host => account.host }
  end
  
  def trial_expiring(user, subscription)
    setup_email(user, 'Trial period expiring')
    setup_bcc
    @body = { :user => user, :subscription => subscription }
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
    setup_bcc
    @body = { :subscription => subscription }    
  end
  
  def plan_changed(subscription)
    setup_email(subscription.account.account_admin, "Your #{AppConfig['app_name']} plan has been changed")
    @body = { :subscription => subscription }    
  end
  
  def password_reset(reset)
    setup_email(reset.user, 'Password Reset Request')
    @body = { :reset => reset }
  end
end
