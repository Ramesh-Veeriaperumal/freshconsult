class Freshfone::OpsNotifier
  include Freshfone::CallbackUrls

  attr_accessor :current_account, :notification, :to_numbers, :message

  def initialize(current_account, notification, options = {})
    self.current_account = current_account
    self.notification = notification || "undefined"
    self.message = options[:message] || 
                     "Alert #{notification} for account #{current_account.id}"
    self.to_numbers = options[:to_numbers] || 
                        FreshfoneConfig['ops_alert']['call']['to']
  end

  def alert
    alert_mail
    alert_call    
  end

  def alert_mail
    FreshfoneNotifier.ops_alert(current_account, notification, message)
  end

  def alert_call
    url = "#{ops_call_notify_url}?message=#{CGI.escape(message)}"
    config_call = 
    to_numbers.each { |number| TwilioMaster.account.calls.create(
      :from => FreshfoneConfig['ops_alert']['call']['from'],
      :to => number,
      :url => url) }
  end

end