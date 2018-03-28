module Va::Webhook::HelperMethods

	def escape_markup_language content
		CGI.escapeHTML content.to_s
	end

	def render_json_string_without_quotes content
		content.to_s.to_json[1..-2]
	end

	def do_percent_encoding content
		ERB::Util.url_encode content.to_s
	end

end
