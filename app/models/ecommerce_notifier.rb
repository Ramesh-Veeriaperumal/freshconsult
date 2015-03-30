class EcommerceNotifier < ActionMailer::Base
	layout "email_font"

    RECIPIENTS = ["jay@freshdesk.com", "sathish@freshdesk.com","priyo@freshdesk.com", "janani@freshdesk.com"]

  def invalid_account(ecom_name, account)
    headers = {
      :subject => "Your Ecommerce account #{ecom_name} is suspended",
      :from    => AppConfig['from_email'],
      :to      => account.admin_email,
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @account = account
    @ecom_name = ecom_name

    mail(headers) do |part|
      part.text do
        render "invalid_account.text.plain"
      end
      part.html do
        render "invalid_account.text.html"
      end
    end.deliver
  end

  def account_activation(ecom_name, account)
    headers = {
      :subject   => "Your Ecommerce account #{ecom_name} is activated",
      :from      => AppConfig['from_email'],
      :to        => account.admin_email,
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    } 
    @account = account
    @ecom_name = ecom_name

    mail(headers) do |part|
      part.text do
        render "account_activation.text.plain"
      end
      part.html do
        render "account_activation.text.html"
      end
    end.deliver
  end

  def token_expiry(ecom_name, account, expiry_date)
    headers = {
      :subject   => "Ecommerce account #{ecom_name} token expiration",
      :from      => AppConfig['from_email'],
      :to        => account.admin_email,
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    } 
    @account = account
    @ecom_name = ecom_name
    
    mail(headers) do |part|
      part.text do
        render "token_expiry.text.plain"
      end
      part.html do
        render "token_expiry.text.html"
      end
    end.deliver
  end

  def dev_notify(msg, call, args, account)
    headers = {
      :subject   => "Ecommerce error for account #{account.name} ",
      :from      => AppConfig['from_email'],
      :to        => RECIPIENTS,
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @msg = msg
    @call = call
    @args = args
    @account = account

    mail(headers) do |part|
      part.html do
        render "dev_notify.html"
      end
    end.deliver
  end
	
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end