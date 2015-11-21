class FreshfoneNotifier < ActionMailer::Base
  layout "email_font"

  def account_expiring(account, trial_days = nil)
    headers = {
      :subject       => "Warning. Your phone trial will expire in #{trial_days}",
      :to            => account.admin_email,
      :from          => AppConfig['billing_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @trial_days = trial_days
    @account = account
    mail(headers) do |part|
      part.html { render "account_expiring", :formats => [:html] }
    end.deliver
  end

  def number_renewal_failure(account, number, low_balance_message='')
    headers = {
      :subject     => "Renewal failed for your Freshfone Number #{number}  #{low_balance_message}",
      :to          => account.admin_email,
      :from        => AppConfig['billing_email'],
      :sent_on     => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    @number  = number
    mail(headers) do |part|
      part.html { render "number_renewal_failure", :formats => [:html] }
    end.deliver
  end

  def suspended_account(account)
    headers = {
      :subject => "Your phone channel is temporarily suspended",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @body = { :account => account }
    @account = account
    mail(headers) do |part|
      part.html { render "suspended_account", :formats => [:html]}
    end.deliver
  end

  def recharge_success(account, recharge_amount, balance)
    headers = {
      :subject => 'Phone credit recharge successful',
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on  => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @recharge_amount = recharge_amount
    @balance         = balance
    @account         = account

    mail(headers) do |part|
      part.html { render "recharge_success", :formats => [:html]}
    end.deliver
  end

  def low_balance(account, balance)
    headers = {
      :subject => 'Warning. Low on Phone credits',
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    @balance = balance
    mail(headers) do |part|
      part.html { render "low_balance", :formats => [:html] }
    end.deliver
  end

  def trial_number_expiring(account, number, trial_days = nil)
    headers = {
      :subject => 'Warning. Phone trial about to expire',
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account  = account
    @number   = number
    @trial_days = trial_days
    mail(headers) do |part|
      part.html { render "trial_number_expiring" }
    end.deliver
  end 
 
  def billing_failure(account, args, current_call, exception)
    headers = {
      :subject => "Phone Credit Calculation Error for #{account.id} :: call sid :#{args[:call_sid]}",
      :to      => FreshfoneConfig['billing_error_email'],
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    @args = args
    @call = current_call
    @exception = exception
    mail(headers) do |part|
      part.html { render "billing_failure" }
    end.deliver
  end


  def recharge_failure(account, recharge_amount, balance)
    headers = {
      :subject => 'Failed to recharge phone credits',
      :to => account.admin_email,
      :from => AppConfig['billing_email'],
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    @recharge_amount = recharge_amount
    @balance = balance
    mail(headers) do |part|
      part.html { render "recharge_failure" }
    end.deliver
  end

  def ops_alert(account, notification, message)
    headers = {
      :subject => "Alert #{notification} for account #{account.id}",
      :to      => FreshfoneConfig['ops_alert']['mail']['to'],
      :from    => FreshfoneConfig['ops_alert']['mail']['from'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
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
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @message = params[:message]
    mail(headers) do |part|
      part.html { render "freshfone_email_template" }
    end.deliver
  end

  def freshfone_ops_notifier(account, params)
    params[:subject] ||= params[:message]
    params[:recipients]  =  FreshfoneConfig['ops_alert']['mail']['to']
    params[:from]        =  FreshfoneConfig['ops_alert']['mail']['from']
    freshfone_email_template(account, params)
  end

  def freshfone_request_template(account, user, params)
    headers = {
      :subject => params[:subject],
      :to      => FreshfoneConfig['freshfone_request']['to'],
      :from    => params[:from],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @user = user
    @message = params[:message]
    mail(headers) do |part|
      part.html { render "freshfone_request_template", :formats => [:html] }
    end.deliver
  end


  def freshfone_account_closure(account)
    headers = {
      :subject => "Process Account closure for account #{account.id}",
      :to      => FreshfoneConfig['ops_alert']['mail']['to'],
      :from    => FreshfoneConfig['ops_alert']['mail']['from'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    mail(headers) do |part|
      part.html { render "freshfone_account_closure" }
    end.deliver
  end

  def call_recording_deletion_failure(params)
  	headers = {
  		:subject => "Error on Call Recording Deletion in Twilio",
  		:to => FreshfoneConfig['ops_alert']['mail']['to'],
  		:from => FreshfoneConfig['ops_alert']['mail']['from'],
  		:sent_on => Time.now,
  		"Reply-to" => "",
  		"Auto-Submitted" => "auto-generated",
  		"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
  	}
  	@params = params
  	mail(headers) do |part|
  		part.html { render "call_recording_deletion_failure"}
  	end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end