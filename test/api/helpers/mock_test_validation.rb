class MockTestValidation
  attr_accessor :error_options

  def initialize(*_args)
    @error_options = {}
  end
end
