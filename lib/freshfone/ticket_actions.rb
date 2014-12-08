module Freshfone::TicketActions
	include Freshfone::CallHistory

	def create_note
		@ticket = current_account.tickets.find_by_display_id(params[:ticket])
		
		if @ticket.present? && build_note(params.merge({ :agent => agent })).save
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.note.human_name'),
					:link => @template.comment_path({ 'ticket_id' => current_call.notable.notable.display_id, 
																						'comment_id' => current_call.notable_id }, 
																					t(:'freshfone.note.view'), 
																					{ :'data-pjax' => "#body-container" }),
 				}).html_safe
		else
			flash[:notice] = t(:'flash.general.create.failure',
													{ :human_name => t(:'freshfone.note.human_name') })
		end
		respond_to do |format|
			format.js { }
		end
	ensure
		update_user_presence unless call_history?
	end

	def create_ticket
		json_response = {}
		if build_ticket(params.merge!({ :agent => agent })).save
			@ticket = current_call.notable
			build_note(params.merge({ :is_recording_note => 'true' })).save if current_call.freshfone_number.private_recording?
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.ticket.human_name'),
					:link => @template.link_to(t(:'freshfone.ticket.view'),
						helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
			json_response = {:success => true, :ticket => {:display_id =>@ticket.display_id , :subject => @ticket.subject , :status_name => @ticket.status_name, :priority => @ticket.priority}}
		else
			flash[:notice] = t(:'flash.general.create.failure',
													{ :human_name => t(:'freshfone.ticket.human_name') })
			json_response = {:success => false}
		end
		respond_to do |format|
			format.xml { return empty_twiml }
			format.js { }
			format.nmobile { render :json => json_response }
		end
	ensure
		update_user_presence unless call_history?
	end

	def voicmail_ticket(args)
		build_ticket(args).save
		@ticket = current_call.notable
		build_note(args.merge({ :is_recording_note => 'true' })).save if current_call.freshfone_number.private_recording?
	end

	private
		def build_ticket(args)
			current_call.notable = Account.current.tickets.build
			current_call.initialize_ticket(args)
		end

		def build_note(args)
			current_call.notable = @ticket.notes.build
			current_call.initialize_notes(args)
		end

		def agent
			agent_id =  call_history? ? params[:responder_id] : params[:agent]
			fetch_calling_agent(agent_id) || current_user
		end

		def fetch_calling_agent(agent_id)
			current_account.users.technicians.visible.find_by_id(agent_id) unless agent_id.blank?
		end

		def update_user_presence
			agent.freshfone_user.reset_presence.save unless agent.blank?
		end
		
		def call_history?
			params[:call_history].present? && params[:call_history].to_bool
		end

end
