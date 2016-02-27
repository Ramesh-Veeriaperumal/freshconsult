class MockTestValidation
  attr_accessor :error_options
  
  def initialize(*args)
    @error_options = {}
  end
end
