module Helpdesk::MergeTicketActions

	include Helpdesk::Ticketfields::TicketStatus
	include Helpdesk::ToggleEmailNotification
	include ParserUtil
	include RedisKeys

	def handle_merge 
    @header = @target_ticket.header_info || {}
    @source_tickets.each do |source_ticket|
			move_source_time_sheets_to_target(source_ticket)
			move_source_description_to_target(source_ticket)
			close_source_ticket(source_ticket)
			update_header_info(source_ticket.header_info) if source_ticket.header_info
			update_merge_activity(source_ticket) 
		end
    move_source_notes_to_target
		add_header_to_target if !@header.blank?
		move_source_requesters_to_target
		add_note_to_target_ticket
	end

	private

		def move_source_notes_to_target
			Resque.enqueue( Workers::MergeTickets,{ :source_ticket_ids => @source_tickets.map(&:display_id),
                                              :target_ticket_id => @target_ticket.id, 
                                              :source_note_private => params[:source][:is_private],
                                              :source_note => params[:source][:note] })
	  end

		def move_source_description_to_target source_ticket
			desc_pvt_note = params[:target][:is_private]
			source_description_note = @target_ticket.notes.build(
				:body_html => build_source_description_body_html(source_ticket),
				:private => desc_pvt_note || false,
				:source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
				:account_id => current_account.id,
				:user_id => current_user && current_user.id
			)
			add_source_attachments_to_source_description(source_ticket, source_description_note)
			source_description_note.save
		end

    def build_source_description_body_html source_ticket
      %{#{I18n.t('helpdesk.merge.bulk_merge.target_merge_description1', :ticket_id => source_ticket.display_id)}<br/><br/>
      <b>#{I18n.t('Subject')}:</b> #{source_ticket.subject}<br/><br/>
      <b>#{I18n.t('description')}:</b><br/>#{source_ticket.description_html}}
    end

		def add_source_attachments_to_source_description( source_ticket , source_description_note )
      ## handling attachemnt..need to check this
			source_ticket.attachments.each do |attachment|      
				url = attachment.authenticated_s3_get_url
				io = open(url) #Duplicate code from helpdesk_controller_methods. Refactor it!
				if io
					def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
				end
				source_description_note.attachments.build(:content => io, :description => "",
																									:account_id => source_description_note.account_id)
			end
		end

		def move_source_requesters_to_target
			cc_email_array = @source_tickets.collect{ |source| [ get_cc_email_from_hash(source), 
																	convert_to_cc_format(source) ] if check_source(source) }.flatten().compact
			return unless cc_email_array.any?
			if @target_ticket.cc_email.blank?
				@target_ticket.cc_email = {:cc_emails => cc_email_array.uniq, :fwd_emails => []}
			else	
				cc_email_array += get_cc_email_from_hash(@target_ticket) 
				@target_ticket.cc_email[:cc_emails] = validate_emails(cc_email_array , @target_ticket)
			end
			@target_ticket.save  
		end  

		def update_merge_activity source_ticket
		  source_ticket.create_activity(current_user, 'activities.tickets.ticket_merge.long',
		        {'eval_args' => {'merge_ticket_path' => ['merge_ticket_path', 
		        {'ticket_id' => @target_ticket.display_id, 'subject' => @target_ticket.subject}]}}, 
		        											'activities.tickets.ticket_merge.short') 
		end

		def move_source_time_sheets_to_target source_ticket
		  source_ticket.time_sheets.each do |time_sheet|
		    time_sheet.update_attribute(:workable_id, @target_ticket.id)
		  end
		end

		def close_source_ticket source_ticket
		  disable_notification
		  source_ticket.update_attribute(:status , CLOSED)
		  enable_notification
		end

		def update_header_info source_header
			source_header[:message_ids].each do |source|
				@header[:message_ids] = [] unless @header.key?(:message_ids)
				unless @header[:message_ids].include? source
					@header[:message_ids] << source
					source_key = EMAIL_TICKET_ID % { :account_id => current_account.id, :message_id => source }
					set_key(source_key, @target_ticket.display_id)
				end
			end
		end

		def add_header_to_target
			@target_ticket.header_info = @header
			@target_ticket.schema_less_ticket.save
		end

		def add_note_to_target_ticket
		  target_pvt_note = @target_ticket.requester_has_email? ? params[:target][:is_private] : true
			@target_note = @target_ticket.notes.create(
				:body_html => params[:target][:note],
				:private => target_pvt_note  || false,
				:source => target_pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : 
																Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
				:account_id => current_account.id,
				:user_id => current_user && current_user.id,
				:from_email => @target_ticket.reply_email,
				:to_emails => target_pvt_note ? [] : @target_ticket.requester.email.to_a,
				:cc_emails => target_pvt_note ? [] : @target_ticket.cc_email_hash && @target_ticket.cc_email_hash[:cc_emails]
			)
			if !@target_note.private
  			Helpdesk::TicketNotifier.send_later(:deliver_reply, @target_ticket, @target_note, {:include_cc => true})
			end
		end

		def convert_to_cc_format ticket
		  %{#{ticket.requester} <#{ticket.requester.email}>}
		end

    def get_cc_email_from_hash ticket
      ticket.cc_email ? (ticket.cc_email[:cc_emails] ? ticket.cc_email[:cc_emails] : []) : []
    end 

		def check_source source_ticket
		  source_ticket.requester_has_email? and ( !source_ticket.requester.eql?(@target_ticket.requester) or 
		  																									get_cc_email_from_hash(source_ticket).any?)
		end
end	
