module LiquidSyntaxParser
  def syntax_rescue(param, param_name = nil)
    Liquid::Template.parse(param.presence)
  	rescue Exception => e
  		if param_name.nil?
  			@errors ||= []
  			@errors <<  h(e.to_s)
  		else
  			@errors ||= {}
  			@errors[param_name] ||= []
  			@errors[param_name] <<  h(e.to_s)
  		end
	end
end
