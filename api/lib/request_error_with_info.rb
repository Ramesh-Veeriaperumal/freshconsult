class RequestErrorWithInfo < BaseError
  attr_accessor :code, :additional_info
  def initialize(type, params_hash = {}, additional_info = {})
    super(type, params_hash)
    @code = type.to_s
    @additional_info = additional_info
  end
end
