class FreshfoneNotifier < ActionMailer::Base
  layout "email_font"

  def account_expiring(account, trial_days = nil)
    subject       "Your Freshfone account will expire in #{trial_days}"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :account => account, :trial_days => trial_days
    sent_on       Time.now
    content_type  "text/html"
  end

  def number_renewal_failure(account, number)
    subject       "Renewal failed for your Freshfone Number #{number}"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :account => account, :number => number
    sent_on       Time.now
    content_type  "text/html"
  end

  def suspended_account(account)
    subject       "Your Freshfone account is temporarily suspended"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :account => account
    sent_on       Time.now
    content_type  "text/html"
  end

  def address_certification(account, number)
    subject       "Freshfone: Certify your address"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :freshfone_number => number
    sent_on       Time.now
    content_type  "text/html"
  end

  def recharge_success(account, recharge_amount, balance)
    subject       "Your Freshfone credit has been recharged!"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :recharge_amount => recharge_amount, :balance => balance
    sent_on       Time.now
    content_type  "text/html"
  end

  def low_balance(account, balance)
    subject       "Your Freshfone credit is running low!"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :account => account, :balance => balance
    sent_on       Time.now
    content_type  "text/html"
  end

  def trial_number_expiring(account, number, trial_days = nil)
    subject       "Your Freshfone number #{number} will expire in #{trial_days}"
    recipients    account.admin_email
    from          AppConfig['billing_email']
    body          :account => account, :number => number, :trial_days => trial_days
    sent_on       Time.now
    content_type  "text/html"
  end 
 
  def billing_failure(account, call_sid, exception)
    subject       "Freshfone Credit Calculation Error for #{account.id} :: call sid :#{call_sid}"
    recipients    FreshfoneConfig['billing_error_email']
    from          AppConfig['billing_email']
    body          :account => account, :call_sid => call_sid, :exception => exception
    sent_on       Time.now
    content_type  "text/html"
  end

  def ops_alert(account, notification, message)
    subject       "Alert #{notification} for account #{account.id}"
    recipients    FreshfoneConfig['ops_alert']['mail']['to']
    from          FreshfoneConfig['ops_alert']['mail']['from']
    body          :account => account, :message => message
    sent_on       Time.now
    content_type  "text/html"
  end

  def freshfone_email_template(account, params)
    subject      params[:subject]
    recipients   params[:recipients]
    from         params[:from]
    body         :account => account, :message => params[:message]
    sent_on      Time.now
    content_type "text/html"
  end

end