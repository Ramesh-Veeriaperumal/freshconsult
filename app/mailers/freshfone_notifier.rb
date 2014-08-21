class FreshfoneNotifier < ActionMailer::Base
  layout "email_font"

  def account_expiring(account, trial_days = nil)
    headers = {
      :subject       => "Your Freshfone account will expire in #{trial_days}",
      :to            => account.admin_email,
      :from          => AppConfig['billing_email'],
      :sent_on       => Time.now
    }
    @trial_days = trial_days
    @account = account
    mail(headers) do |part|
      part.html { render "account_expiring.html" }
    end.deliver
  end

  def number_renewal_failure(account, number)
    headers = {
      :subject     => "Renewal failed for your Freshfone Number #{number}",
      :to          => account.admin_email,
      :from        => AppConfig['billing_email'],
      :sent_on     => Time.now
    }
    @account = account
    @number  = number
    mail(headers) do |part|
      part.html { render "number_renewal_failure.html" }
    end.deliver
  end

  def suspended_account(account)
    headers = {
      :subject => "Your Freshfone account is temporarily suspended",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now
    }
    @body = { :account => account }
    @account = account
    mail(headers) do |part|
      part.html { render "suspended_account.html" }
    end.deliver
  end

  def address_certification(account, number)
    headers = {
      :subject => "Freshfone: Certify your address",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now
    }
    @freshfone_number = number
    mail(headers) do |part|
      part.html { render "address_certification.html" }
    end.deliver
  end

  def recharge_success(account, recharge_amount, balance)
    headers = {
      :subject => "Your Freshfone credit has been recharged!",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on  => Time.now
    }
    @recharge_amount = recharge_amount
    @balance         = balance

    mail(headers) do |part|
      part.html { render "recharge_success.html"}
    end.deliver
  end

  def low_balance(account, balance)
    headers = {
      :subject => "Your Freshfone credit is running low!",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now
    }
    @account = account
    @balance = balance
    mail(headers) do |part|
      part.html { render "low_balance.html" }
    end.deliver
  end

  def trial_number_expiring(account, number, trial_days = nil)
    headers = {
      :subject => "Your Freshfone number #{number} will expire in #{trial_days}",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now
    }
    @account  = account
    @number   = number
    @trial_days = trial_days
    mail(headers) do |part|
      part.html { render "trial_number_expiring" }
    end.deliver
  end 
 
  def billing_failure(account, call_sid, exception)
    headers = {
      :subject => "Freshfone Credit Calculation Error for #{account.id} :: call sid :#{call_sid}",
      :to      => FreshfoneConfig['billing_error_email'],
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now
    }
    @account = account
    @call_sid = call_sid
    @exception = exception
    mail(headers) do |part|
      part.html { render "billing_failure" }
    end.deliver
  end

  def ops_alert(account, notification, message)
    headers = {
      :subject => "Alert #{notification} for account #{account.id}",
      :to      => FreshfoneConfig['ops_alert']['mail']['to'],
      :from    => FreshfoneConfig['ops_alert']['mail']['from'],
      :sent_on => Time.now
    }
    @account = account
    @message = message
    mail(headers) do |part|
      part.html { render "ops_alert" }
    end.deliver
  end

  def freshfone_email_template(account, params)
    headers = {
      :subject => params[:subject],
      :to      => params[:recipients],
      :from    => params[:from],
      :sent_on => Time.now
    }
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @message = params[:message]
    mail(headers) do |part|
      part.html { render "freshfone_email_template" }
    end.deliver
  end

  def freshfone_account_closure(account)
    headers = {
      :subject => "Process Account closure for account #{account.id}",
      :to      => FreshfoneConfig['ops_alert']['mail']['to'],
      :from    => FreshfoneConfig['ops_alert']['mail']['from'],
      :sent_on => Time.now
    }
    @account = account
    mail(headers) do |part|
      part.html { render "freshfone_account_closure" }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end