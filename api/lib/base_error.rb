class BaseError
  attr_accessor :message

  def initialize(value, params_hash = {})
    message = retrieve_message(params_hash[:prepend_msg]) + retrieve_message(value) + retrieve_message(params_hash[:append_msg])
    @message = message % params_hash
  rescue KeyError
    Rails.logger.error("API Error with value :: #{value.inspect} :: message :: #{message.inspect} :: Params: #{params_hash.inspect}")
    raise
  end

  def retrieve_message(value)
    !value.nil? && ErrorConstants::ERROR_MESSAGES.key?(value) ? ErrorConstants::ERROR_MESSAGES[value].to_s : value.to_s
  end
end
