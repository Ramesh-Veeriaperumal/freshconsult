class HashDrop < Liquid::Drop
  
  def initialize(options = {})
    @options = options
  end
  
  def before_method(method)
    escape_html(@options[method.to_sym])
  end

  private

  def escape_html object
    return unless object
    if object.is_a?(Hash)
      Hash[object.map{|k,v| [k,escape_html(v)] } ]
    elsif object.is_a?(Array)
      object.map { |value| escape_html(value) }
    else
      CGI::escapeHTML("#{object}")
    end       
  end
end