class Helpdesk::TicketDrop < BaseDrop

	include ActionController::UrlWriter
	include TicketConstants

	liquid_attributes << :subject << :requester << :group << :ticket_type

	def initialize(source)
		super source
	end

	def id
		@source.display_id
	end

	def raw_id
		@source.id
	end

	def encode_id
		@source.encode_display_id
	end

	def description
	 	@description_with_attachments ||= @source.description_with_attachments
	end

	def description_text
		@source.description
	end

	def agent
		@source.responder
	end

	def status
		@source.status_name
	end

	def requester_status_name
		Helpdesk::TicketStatus.translate_status_name(@source.ticket_status, "customer_display_name")
	end

	def priority
		PRIORITY_NAMES_BY_KEY[@source.priority]
	end

	def source
		SOURCE_NAMES_BY_KEY[@source.source]
	end

	def tags
		@source.tag_names.join(', ')
	end

	def due_by_time
		@source.due_by.strftime("%B %e %Y at %I:%M %p")
	end

	def due_by_hrs
		@source.due_by.strftime("%I:%M %p")
	end

	def fr_due_by_hrs
		@source.frDueBy.strftime("%I:%M %p")
	end

	def url
		helpdesk_ticket_url(@source, :host => @source.account.host, :protocol=> @source.url_protocol)
	end

	def portal_url
		support_ticket_url(@source, :host => @source.portal_host, :protocol=> @source.url_protocol)
	end

	def portal_name
		@source.portal_name
	end

	def latest_public_comment
		@source.liquidize_comment(@source.latest_public_comment)
	end

	def satisfaction_survey		
		Survey.satisfaction_survey_html(@source)
	end

	def custom_field
		@source.custom_field  # For performance reasons, load_flexifield needs to be called by each implementation separately to use this liquid.
	end

end
