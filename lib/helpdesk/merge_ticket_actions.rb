module Helpdesk::MergeTicketActions

	include Helpdesk::Ticketfields::TicketStatus
	include Helpdesk::ToggleEmailNotification
	include ParserUtil

	def handle_merge 
		@source_tickets.each do |source_ticket|
			move_source_notes_to_target(source_ticket)
			move_source_time_sheets_to_target(source_ticket)
			move_source_description_to_target(source_ticket)
			add_note_to_source_ticket(source_ticket) 
			close_source_ticket(source_ticket)
			update_merge_activity(source_ticket) 
		end
		move_source_requesters_to_target
		add_note_to_target_ticket
	end

	private

		def move_source_notes_to_target source_ticket
	    source_ticket.notes.each do |note|
	      note.update_attribute( :notable_id , @target_ticket.id )
	    end
		end

		def move_source_description_to_target source_ticket
			desc_pvt_note = params[:target][:is_private]
			source_description_note = @target_ticket.notes.build(
				:body_html => %{<b>#{source_ticket.subject}</b><br/><br/>#{source_ticket.description}},
				:private => desc_pvt_note || false,
				:source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
				:account_id => current_account.id,
				:user_id => current_user && current_user.id
			)
			add_source_attachments_to_source_description(source_ticket, source_description_note)
			source_description_note.save
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
				cc_email_array += @target_ticket.cc_email[:cc_emails] 
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

		def add_note_to_source_ticket source_ticket
		  pvt_note =  source_ticket.requester_has_email? ? params[:source][:is_private] : true
		    source_note = source_ticket.notes.create(
		      :body => params[:source][:note],
		      :private => pvt_note || false,
		      :source => pvt_note ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] : 
		      											Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
		      :account_id => current_account.id,
		      :user_id => current_user && current_user.id,
		      :from_email => source_ticket.reply_email,
		      :to_emails => pvt_note ? [] : source_ticket.requester.email.to_a,
		      :cc_emails => pvt_note ? [] : source_ticket.cc_email_hash && source_ticket.cc_email_hash[:cc_emails]
		    )
		    if !source_note.private
		      Helpdesk::TicketNotifier.send_later(:deliver_reply, source_ticket, source_note , {:include_cc => true})
		    end
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
		  source_ticket.requester_has_email? && ( !source_ticket.requester.eql?(@target_ticket.requester) or 
		  																									get_cc_email_from_hash(source_ticket).any?)
		end
end	
