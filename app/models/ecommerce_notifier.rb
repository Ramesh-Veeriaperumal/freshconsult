class EcommerceNotifier < ActionMailer::Base
	layout "email_font"

  RECIPIENTS = ["sathish@freshdesk.com", "murugu@freshdesk.com", "priyo@freshdesk.com", "noc@freshdesk.com"]

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
      part.html { render "token_expiry", :formats => [:html] }
    end.deliver
  end

  def notify_threshold_limit(limit)
     headers = {
      :subject   => "Ebay api threshold limit reached",
      :from      => AppConfig['from_email'],
      :to        => RECIPIENTS,
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    } 

    @limit = limit
    
    mail(headers) do |part|
      part.html { render "notify_threshold_limit", :formats => [:html] }
    end.deliver
  end

  def daily_api_usage(file_name)
    headers = {
      :subject   => "Daily api usage",
      :to        => RECIPIENTS,
      :from      => AppConfig['from_email'],
      :sent_on   => Time.now
    }
    attachments[file_name] = {
      :mime_type => 'text/plain; charset=utf-8; header=present',
      :content   => File.read(file_name)
    }
    mail(headers) do |part|
      part.html { render "daily_api_usage", :formats => [:html] }
    end.deliver
  end
	

end