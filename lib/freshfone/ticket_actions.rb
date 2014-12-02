module Freshfone::TicketActions
	include Freshfone::CallHistory

	def create_note
		@ticket = current_account.tickets.find_by_display_id(params[:ticket])
		
		if @ticket.present? && build_note.save
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
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.ticket.human_name'),
					:link => @template.link_to(t(:'freshfone.ticket.view'),
						helpdesk_ticket_path(current_call.notable), :'data-pjax' => "#body-container") }).html_safe
			json_response = {:success => true, :ticket => {:display_id =>current_call.notable.display_id , :subject => current_call.notable.subject , :status_name => current_call.notable.status_name, :priority => current_call.notable.priority}}
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
	end

	private
		def build_ticket(args)
			current_call.notable = Account.current.tickets.build
			current_call.initialize_ticket(args)
		end

		def build_note
			current_call.notable = @ticket.notes.build
			current_call.initialize_notes(params.merge({ :agent => agent }))
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
