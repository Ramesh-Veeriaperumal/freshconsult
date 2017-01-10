module Helpdesk::EmailParser::EmailParseError

	def raise_parse_error(error_message)
		raise Helpdesk::EmailParser::ParseError.new(error_message)
	end

end


