class BaseError
  attr_accessor :message

  def initialize(value, params_hash = {})
    @message = I18n.t("api.error_messages.#{value}", params_hash.merge(:default => value))
  end
end