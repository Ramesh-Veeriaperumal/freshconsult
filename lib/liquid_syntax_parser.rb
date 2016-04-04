module LiquidSyntaxParser

	def syntax_rescue param
		Liquid::Template.parse(param.presence)
	rescue Exception => e
		@errors ||= [] 
		@errors <<  h(e.to_s)
	end
end