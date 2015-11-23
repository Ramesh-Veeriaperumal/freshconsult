class BaseError
  attr_accessor :message

  def initialize(value, params_hash = {})
    message = !value.nil? && ErrorConstants::ERROR_MESSAGES.key?(value) ? ErrorConstants::ERROR_MESSAGES[value].to_s : value.to_s
    @message = message % params_hash
  end
end
