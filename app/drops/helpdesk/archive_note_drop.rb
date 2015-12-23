class Helpdesk::ArchiveNoteDrop < BaseDrop

	include Rails.application.routes.url_helpers

	self.liquid_attributes += [:private]

	def initialize(source)
		super source
	end

	def id
		source.id
	end

	def user
		@source.user
	end

	def commenter
		@source.user
	end
	
	def by_agent
		user.agent && note_ticket.requester_id != user.id
	end

	def note_ticket
		@source.notable
	end

	def description
	 	@source.body_html
	end

	def description_text
		@source.body
	end

	def body
		@source.liquidize_body
	end

	def body_text
		last_reply = Nokogiri::HTML(CGI.unescapeHTML(@source.body_html))
		last_reply.xpath('//div[@class="freshdesk_quote"]').remove
		last_reply.content.strip()
	end

	def created_on
	    @source.created_at
	end

	def survey_result
		@source.survey_remark.survey_result.rating unless @source.survey_remark.nil?
	end

	def attachments
	    @source.all_attachments
	end

	def freshfone_call
		@source.freshfone_call
	end

	def cloud_files
		@source.cloud_files 
	end

end