module Ecommerce::Ebay::ErrorHandler

  def ebay_sandbox
    return_value = false
    @retry = false
    begin
      return_value = yield
    rescue Ecommerce::Ebay::Api::Error::ApiLimitError => e
      @retry = true
      Rails.logger.error "Ebay Throttling error => #{e.message} for account #{Account.current.id}"
    rescue Ecommerce::Ebay::Api::Error::ArgumentError => e
      Rails.logger.error "Ebay argument error => #{e.message} for account #{Account.current.id}"
    rescue Ecommerce::Ebay::Api::Error::AuthenticationError => e
      Rails.logger.error "Ebay argument error => #{e.message} for account #{Account.current.id}"
    rescue Ecommerce::Ebay::Api::Error::ApiError => e
      send_dev_notification(e.message, call,args)
      Rails.logger.error "Ebay Api error => #{e.message} for account #{Account.current.id}"
    rescue Timeout::Error => e
      raise_newrelic_error(e)
    rescue OpenSSL::SSL::SSLError => e
      raise_newrelic_error(e)
    rescue SystemStackError => e
      raise_newrelic_error(e)
    rescue Exception => e
      Rails.logger.debug "Error for account#{Account.current.id}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
      raise_newrelic_error(e)
    end
    
    return_value
  end

  def raise_newrelic_error(exception)
    Rails.logger.error exception.inspect
    Rails.logger.error exception.message
    NewRelic::Agent.notice_error(exception)
  end

  def send_dev_notification(exp_msg, call, args)
    EcommerceNotifier.send_later(:dev_notify, exp_msg, call, args, Account.current)
  end

end