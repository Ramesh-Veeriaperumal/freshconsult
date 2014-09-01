class HashDrop < Liquid::Drop
  
  def initialize(options = {})
    @options = options
  end
  
  def before_method(method)
    CGI::escapeHTML("#{@options[method.to_sym]}")
  end
  
end