class FreshfoneNotifier < ActionMailer::Base
  layout "email_font"
  include EmailHelper

  def account_expiring(account, remaining_days = nil)
    headers = {
      :subject       => "Warning. Your phone channel will expire in #{remaining_days}",
      :to            => account.admin_email,
      :from          => AppConfig['billing_email'],
      :sent_on       => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    headers.merge!(make_header(nil, nil, account.id, "Account Expiring"))
    @remaining_days = remaining_days
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

    headers.merge!(make_header(nil, nil, account.id, "Number Renewal Failure"))
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

    headers.merge!(make_header(nil, nil, account.id, "Suspended Account"))
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

    headers.merge!(make_header(nil, nil, account.id, "Recharge Success"))
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

    headers.merge!(make_header(nil, nil, account.id, "Low Balance"))
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

    headers.merge!(make_header(nil, nil, account.id, "Trial Number Expiring"))
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

    headers.merge!(make_header(nil, nil, account.id, "Billing Failure"))
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

    headers.merge!(make_header(nil, nil, account.id, "Recharge Failure"))
    @account = account
    @recharge_amount = recharge_amount
    @balance = balance
    mail(headers) do |part|
      part.html { render "recharge_failure" }
    end.deliver
  end

  def ops_alert(account, notification, message, recipients = nil)
    recipients ||= []
    recipients << FreshfoneConfig['ops_alert']['mail']['to']
    headers = {
      :subject => "Alert #{notification} for account #{account.id}",
      :to      => recipients,
      :from    => FreshfoneConfig['ops_alert']['mail']['from'],
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    headers.merge!(make_header(nil, nil, account.id, "Ops Alert"))
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

    headers.merge!(make_header(nil, nil, account.id, params[:type]))
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @message = params[:message]
    mail(headers) do |part|
      part.html { render "freshfone_email_template" }
    end.deliver
  end

  def freshfone_ops_notifier(account, params)
    params[:subject] ||= params[:message]
    params[:recipients] ||=   FreshfoneConfig['ops_alert']['mail']['to']
    params[:from]        =  FreshfoneConfig['ops_alert']['mail']['from']
    params[:type]   = "Freshfone Ops Notifier"
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

    headers.merge!(make_header(nil, nil, account.id, params[:type]))
    headers[:cc] = params[:cc] if params[:cc].present?
    @account = account
    @user = user
    @message = params[:message]
    mail(headers) do |part|
      part.html { render "freshfone_request_template", :formats => [:html] }
    end.deliver
  end

  def account_closing(account)
    headers = {
      :subject => 'Phone Channel Closed for your Freshdesk Account',
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      'Reply-to' => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }
    headers.merge!(make_header(nil, nil, account.id, "Account Closing"))
    @account = account
    mail(headers) do |part|
      part.html { render "account_closing", :formats => [:html] }
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

    headers.merge!(make_header(nil, nil, params[:account_id], "Call Recording Deletion Failure"))
  	@params = params
  	mail(headers) do |part|
  		part.html { render "call_recording_deletion_failure"}
  	end.deliver
  end

  def phone_trial_reminder(account, days_left)
    headers = {
      :subject => "Phone Trial will End within #{days_left} days for your Freshdesk Account",
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on => Time.now,
      'Reply-to' => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }

    headers.merge!(make_header(nil, nil, account.id, "Phone Trial Reminder"))
    @account = account
    @days_left = days_left
    mail(headers) do |part|
      part.html { render "phone_trial_expiry_reminder", :formats => [:html] }
    end.deliver
  end

  def customer_mailer(account, subject, partial)
    headers = {
      :subject => subject,
      :to      => account.admin_email,
      :from    => AppConfig['billing_email'],
      :sent_on  => Time.now,
      'Reply-to' => '',
      'Auto-Submitted' => 'auto-generated',
      'X-Auto-Response-Suppress' => 'DR, RN, OOF, AutoReply'
    }

    headers.merge!(make_header(nil, nil, account.id, partial))
    @account = account
    mail(headers) do |part|
      part.html { render partial, :formats => [:html] }
    end.deliver
  end

  def phone_trial_initiated(account)
    customer_mailer(
      account,
      'Enjoy your free phone trial!',
      'phone_trial_initiated')
  end

  def phone_trial_half_way(account)
    customer_mailer(
      account,
      'Do you need help with your phone trial?',
      'phone_trial_half_way')
  end

  def phone_trial_about_to_expire(account)
    customer_mailer(
      account,
      'Your phone trial is about to expire!',
      'phone_trial_about_to_expire')
  end

  def phone_trial_expire(account)
    attachments.inline['request_activation.gif'] = File.read(
      "#{Rails.root}/public/images/freshfone/request_for_activation.gif")
    customer_mailer(
      account,
      'Your phone trial will expire today',
      'phone_trial_expire')
  end

  def trial_number_deletion_reminder(account)
    customer_mailer(
      account,
      'Your phone number will be deleted in 5 days',
      'phone_trial_number_deletion_reminder')
  end

  def trial_number_deletion_reminder_last_day(account)
    customer_mailer(
      account,
      'Your phone number will be deleted today',
      'phone_trial_number_deletion_reminder_last_day')
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
