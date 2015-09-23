module Ecommerce::Ebay::ErrorHandler

  def ebay_sandbox
    return_value = false
    begin
      return_value = yield
    rescue Ecommerce::Ebay::Api::Error::ApiLimitError => e
      Rails.logger.error "Ebay Throttling error => #{e.message} for account #{Account.current.id}"
    rescue Ecommerce::Ebay::Api::Error::ArgumentError => e
      raise_newrelic_error(e)
    rescue Ecommerce::Ebay::Api::Error::AuthenticationError => e
      Rails.logger.error "Ebay argument error => #{e.message} for account #{Account.current.id}"
    rescue Ecommerce::Ebay::Api::Error::ApiError => e
      raise_newrelic_error(e)
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

end