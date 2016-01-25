class Helpdesk::TicketDrop < BaseDrop

	include Rails.application.routes.url_helpers
	include TicketConstants
	include DateHelper

	self.liquid_attributes += [ :requester , :group , :ticket_type , :deleted, :company	]

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

	def from_email
		@source.from_email
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

	def freshfone_call
		@source.freshfone_call
	end

	def cloud_files
	    @source.cloud_files
	end

	def requester
		@source.requester.presence
	end

	def outbound_initiator
		@source.outbound_initiator.presence
	end

	def outbound_email?
		@source.outbound_email?
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

	def sla_policy_name
		@source.sla_policy_name.to_s
	end

	def url
		helpdesk_ticket_url(@source, :host => @source.account.host, :protocol=> @source.url_protocol)
	end

	def full_domain_url
		support_ticket_url(@source, :host => @source.account.full_domain, :protocol=> @source.url_protocol)
	end

	def public_url
		return "" unless @source.account.features_included?(:public_ticket_url)

		access_token = @source.access_token.blank? ? @source.get_access_token : @source.access_token

		public_ticket_url(access_token,:host => @source.portal_host, :protocol=> @source.url_protocol)
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

	def billable_hours
		@billable_hours ||= @source.billable_hours
	end

	def total_time_spent
		@formatted_time ||= @source.time_tracked_hours
	end

	def satisfaction_survey
		@satisfaction_survey ||= begin
			if @source.account.new_survey_enabled?
				CustomSurvey::Survey.satisfaction_survey_html(@source)
			else
				Survey.satisfaction_survey_html(@source)
			end
		end
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
		mappings = @source.custom_field_type_mappings
		field_name = "#{method}_#{@source.account_id}"
		if custom_fields[field_name]
			mappings[field_name] == "custom_date" ? formatted_date(custom_fields[field_name]) : 
                                                                custom_fields[field_name]
		else
			super
		end
	end

	def current_portal
		@portal
	end

end
