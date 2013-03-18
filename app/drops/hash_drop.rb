class HashDrop < Liquid::Drop
  
  def initialize(options = {})
    @options = options
  end
  
  def before_method(method)
    @options[method.to_sym]
  end
  
end