class RequestError < BaseError
  attr_accessor :code
  def initialize(type, params_hash = {})
    super(type, params_hash)
    @code = type.to_s
  end
end