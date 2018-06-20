class PortalValidation < ApiValidation
  attr_accessor :id

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
