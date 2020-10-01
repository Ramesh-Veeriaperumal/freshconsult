class Helpdesk::ArchiveTicketDrop < BaseDrop

	include Rails.application.routes.url_helpers
	include TicketConstants

	self.liquid_attributes += [ :requester , :group , :ticket_type , :deleted	]

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
	  @source.all_attachments
	end
	
	def cloud_files
	  @source.cloud_files 
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

	def priority
		TicketConstants.priority_list[@source.priority]
	end

  def source
    if @source.account.ticket_source_revamp_enabled?
      @source.source_name
    else
      TicketConstants.source_list[@source.source]
    end
  end

	def source_name
		@source.source_name
	end

	def portal_name
		@source.portal_name
	end

	def product_description
		@source.product ? @source.product.description : ""
	end

	def public_comments
		# source.notes.public.exclude_source('meta').newest_first
		@source.public_notes.exclude_source(Account.current.helpdesk_sources.note_exclude_sources)
	end

	def total_time_spent
		@formatted_time ||= calculate_time_spent
	end

	def satisfaction_survey		
		Survey.satisfaction_survey_html(@source)
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
		@source.status_updated_at
	end

	def freshness
		@source.freshness.to_s
	end

	def closed?
		@source.closed?
	end

	def active?
		@source.active?
	end

	def current_portal
		@portal
	end

	private 

		def calculate_time_spent
			minutes = @source.time_sheets.inject(0){ |total,time_sheet| total + time_sheet.time_spent }/60
			"%02d:%02d" % [ minutes/60, minutes%60] 
		end
end
