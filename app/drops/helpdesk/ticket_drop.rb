class Helpdesk::TicketDrop < BaseDrop

	include ActionController::UrlWriter
	include TicketConstants

	liquid_attributes << :requester << :group << :ticket_type

	def initialize(source)
		super source
	end

	def subject
		h(@source.subject)
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

	def requester
		@source.requester.presence
	end

	def agent
		@source.responder.presence
	end

	def status
		@source.status_name
	end

	def requester_status_name
		@source.requester_status_name
	end

	def priority
		PRIORITY_NAMES_BY_KEY[@source.priority]
	end

	def source
		SOURCE_NAMES_BY_KEY[@source.source]
	end

	def source_name
		@source.source_name
	end

	def tags
		@source.tag_names.join(', ')
	end

	def due_by_time
		in_user_time_zone(@source.due_by).strftime("%B %e %Y at %I:%M %p")
	end

	def due_by_hrs
		in_user_time_zone(@source.due_by).strftime("%I:%M %p")
	end

	def fr_due_by_hrs
		in_user_time_zone(@source.frDueBy).strftime("%I:%M %p")
	end

	def url
		helpdesk_ticket_url(@source, :host => @source.account.host, :protocol=> @source.url_protocol)
	end

	def public_url
		@source.populate_access_token if @source.access_token.blank?

		public_ticket_url(@source.access_token,:host => @source.portal_host, :protocol=> @source.url_protocol)
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

	def public_comments
		# source.notes.public.exclude_source('meta').newest_first
		@source.public_notes.exclude_source('meta')
	end

	def satisfaction_survey		
		Survey.satisfaction_survey_html(@source)
	end

	def in_user_time_zone(time)
		return time unless portal_user
		user_time_zone = portal_user.time_zone 
		time.in_time_zone(user_time_zone)
	end

	def created_on
		@source.created_at
	end

	def modified_on
		@source.updated_at
	end

	def status_changed_on
		@source.ticket_states.status_updated_at
	end

	def freshness
		@source.freshness
	end

	def close_ticket_url
		@close_ticket_url ||= close_support_ticket_path(@source, :host => @source.portal_host, :protocol=> @source.url_protocol)
	end

	def closed?
		@source.closed?
	end

	def before_method(method)
		custom_fields = @source.load_flexifield
		if custom_fields["#{method}_#{@source.account_id}"]
			custom_fields["#{method}_#{@source.account_id}"]
		else
			super
		end
	end
end
