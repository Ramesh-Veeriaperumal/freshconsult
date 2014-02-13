class Helpdesk::TicketDrop < BaseDrop

	include ActionController::UrlWriter
	include TicketConstants

	liquid_attributes << :requester << :group << :ticket_type << :deleted	

	def initialize(source)
		super source
	end

	def subject
		@source.subject
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

	def description_html
		@source.description_html
	end

	def attachments
	    @source.attachments
	end

	def dropboxes
	    @source.dropboxes if @source.dropboxes.present?
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
		TicketConstants.priority_list[@source.priority]
	end

	def source
		TicketConstants.source_list[@source.source]
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

	def fr_due_by_time
		in_user_time_zone(@source.frDueBy).strftime("%B %e %Y at %I:%M %p")
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

	def product_description
		@source.product ? @source.product.description : ""
	end

	def latest_public_comment
		@last_public_comment ||= @source.liquidize_comment(@source.latest_public_comment)
	end

	def latest_private_comment
		@last_private_comment ||= @source.liquidize_comment(@source.latest_private_comment)
	end

	def public_comments
		# source.notes.public.exclude_source('meta').newest_first
		@source.public_notes.exclude_source('meta')
	end

	def total_time_spent
		@formatted_time ||= calculate_time_spent
	end

	def satisfaction_survey		
		Survey.satisfaction_survey_html(@source)
	end

	def surveymonkey_survey
		Integrations::SurveyMonkey.survey_html(@source)
	end

	def in_user_time_zone(time)
		portal_user_or_account = (portal_user || portal_account)
		portal_user_or_account.blank? ? time : time.in_time_zone(portal_user_or_account.time_zone)
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
		@source.freshness.to_s
	end

	def close_ticket_url
		@close_ticket_url ||= close_support_ticket_path(@source, :host => @source.portal_host, :protocol=> @source.url_protocol)
	end

	def closed?
		@source.closed?
	end

	def active?
		@source.active?
	end

	def before_method(method)
		custom_fields = @source.custom_field
		if custom_fields["#{method}_#{@source.account_id}"]
			custom_fields["#{method}_#{@source.account_id}"]
		else
			super
		end
	end

	private 

		def calculate_time_spent
			minutes = @source.time_sheets.inject(0){ |total,time_sheet| total + time_sheet.time_spent }/60
			"%02d:%02d" % [ minutes/60, minutes%60] 
		end
end
