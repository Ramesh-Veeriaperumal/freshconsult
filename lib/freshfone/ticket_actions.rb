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
		if build_ticket.save
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.ticket.human_name'),
					:link => @template.link_to(t(:'freshfone.ticket.view'),
						helpdesk_ticket_path(current_call.notable), :'data-pjax' => "#body-container") }).html_safe
		else
			flash[:notice] = t(:'flash.general.create.failure',
													{ :human_name => t(:'freshfone.ticket.human_name') })
		end
		respond_to do |format|
			format.xml { return empty_twiml }
			format.js { }
		end
	ensure
		update_user_presence unless call_history?
	end

	private
		def build_ticket
			current_call.notable = current_account.tickets.build
			current_call.initialize_ticket(params.merge({ :agent => agent }))
		end

		def build_note
			current_call.notable = @ticket.notes.build
			current_call.initialize_notes(params.merge({ :agent => agent }))
		end

		def agent
			fetch_calling_agent(params[:agent]) || current_user
		end

		def fetch_calling_agent(agent_id)
			current_account.users.technicians.visible.find_by_id(agent_id) unless agent_id.blank?
		end

		def update_user_presence
			agent.freshfone_user.reset_presence.save unless agent.blank?
		end
		
		def call_history?
			params[:call_history].to_bool
		end

end