module Freshfone::TicketActions
	include Freshfone::CallHistory
	include Freshfone::NumberValidator

	def create_note
		@ticket = current_account.tickets.find_by_display_id(params[:ticket])
		select_current_call
		if @ticket.present? && build_note(params.merge({ :agent => agent })).save
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.note.human_name'),
					:link => view_context.comment_path({ 'ticket_id' => current_call.notable.notable.display_id, 
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
		select_current_call
		return handle_invalid_number if invalid_requester_number?
		if build_ticket(params.merge!({ :agent => agent })).save
			@ticket = current_call.notable
			build_note(params.merge({ :is_recording_note => 'true' })).save if private_recording?
			flash[:notice] = t(:'freshfone.create.success.with_link',
				{ :human_name => t(:'freshfone.ticket.human_name'),
					:link => view_context.link_to(t(:'freshfone.ticket.view'),
						helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
			json_response = { success: true, ticket: { display_id: @ticket.display_id,
				subject: @ticket.subject, status_name: @ticket.status_name, priority: @ticket.priority } }
		else
			flash[:notice] = t(:'flash.general.create.failure',
													{ :human_name => t(:'freshfone.ticket.human_name') })
			json_response = { success: false }
		end
		respond_to do |format|
			format.xml { return empty_twiml }
			format.js { }
			format.nmobile { render json: json_response }
		end
	ensure
		update_user_presence unless call_history?
	end


    def select_current_call
      return if current_call.blank? || call_history?
      @current_call = current_call.parent if 
      	current_call.parent.present? && current_call.missed_or_busy?
    end


	def voicmail_ticket(args)
		args.merge!({:agent => fetch_calling_agent(args[:agent])}) if args[:agent].present?
		build_ticket(args).save
		@ticket = current_call.notable
	end

	def transcribed_note(args)
		@ticket = current_account.tickets.find(args[:ticket])
		build_note(args).save
		reset_notable
	end

	private
		def build_ticket(args)
			current_call.notable = Account.current.tickets.build
			ActiveRecord::Base.transaction do
				current_call.initialize_ticket(args)
			end
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
			Account.current.users.technicians.visible.find_by_id(agent_id) unless agent_id.blank?
		end

		def update_user_presence
			Rails.logger.debug "Update user presence from Ticket Actions  :: account => #{current_account.id}
						 agent_with_active_call => #{agent_with_active_call?} :: agent => #{agent}"
			return if (agent.blank? || agent_with_active_call?)
			ff_user = agent.freshfone_user
			ff_user.reset_presence.save unless ff_user.acw?
		end
		
		def call_history?
			params[:call_history].present? && params[:call_history].to_bool
		end

		def private_recording?
			current_call.freshfone_number.private_recording? && current_call.freshfone_number.record?
		end

		def agent_with_active_call?
			current_account.freshfone_calls.agent_active_calls(agent.id).present?
		end

    def validate_ticket_creation
      return render json: { status: :error } if current_call.blank?
    end

    def reset_notable
      current_call.notable = @ticket
      current_call.save
    end

    def invalid_requester_number?
      params[:custom_requester_id].blank? && params[:phone_number].present? &&
    		fetch_country_code(params[:phone_number]).blank?
    end

    def handle_invalid_number
      @invalid_phone = true
      respond_to do |format|
      	format.xml { return empty_twiml }
        format.js { }
        format.nmobile { render json: { success: false }}
      end
    end
end
