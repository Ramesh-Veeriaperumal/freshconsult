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
 
  def billing_failure(account, call_sid,dial_call_sid)
    subject       "Freshfone account Credit Calculation Error for  #{account.id} :: call sid :#{call_sid}"
    recipients    AppConfig['freshfone_billing_error_email']
    from          AppConfig['billing_email']
    body          :account => account, :call_sid => call_sid
    sent_on       Time.now
    content_type  "text/html"
  end
end