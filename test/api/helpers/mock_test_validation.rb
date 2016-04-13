class MockTestValidation
  attr_accessor :error_options

  def initialize(*_args)
    @error_options = {}
  end

  def check_params_set(request_params)
  	request_params.each_pair do |key, value|
      instance_variable_set("@#{key}_set", true)
    end
  end
end
