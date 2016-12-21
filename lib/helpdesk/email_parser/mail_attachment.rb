class Helpdesk::EmailParser::MailAttachment < StringIO

	attr_accessor :original_filename, :content_type, :content_id, :is_inline_attachment

	def is_inline_attachment?
		!!is_inline_attachment
	end
end

