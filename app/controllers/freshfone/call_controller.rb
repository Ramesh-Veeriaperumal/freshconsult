class Freshfone::CallController < FreshfoneBaseController
	include Freshfone::FreshfoneUtil
	include Freshfone::CallHistory
	include Freshfone::Presence
	include Freshfone::NumberMethods
	include Freshfone::CallsRedisMethods
	include Freshfone::TicketActions
	include Freshfone::Call::EndCallActions
	
	include Freshfone::Search
	include Freshfone::CallerLookup
	before_filter :load_user_by_phone, :only => [:caller_data]
	before_filter :set_native_mobile, :only => [:caller_data]
	before_filter :populate_call_details, :only => [:status]
	before_filter :set_abandon_state, :only => [:status]
	before_filter :force_termination, :only => [:status]
	before_filter :clear_client_calls, :only => [:status]
	before_filter :reset_outgoing_count, :only => [:status]
	
	include Freshfone::Call::CallCallbacks
	include Freshfone::Call::BranchDispatcher

	def caller_data
    respond_to do |format|
      format.nmobile {
        render :json => {
          :user_name => (@user || {})[:name],
          :call_meta => call_meta
        }
      }
      format.json {
				render :json => {
     		  :user_hover => render_to_string(:partial => 'layouts/shared/freshfone/caller_photo', 
					:locals => { :user => @user }),
		      :user_name => caller_lookup(params[:PhoneNumber],@user),
  	 		  :user_id => (@user || {})[:id],
          :call_meta => call_meta,
          :caller_card => caller_card
    		}
      }
	  end
	end

	def status
		begin
			handle_end_call
		rescue Exception => e
			notify_error({:ErrorUrl => e.message})
			return empty_twiml
		ensure
			add_cost_job
		end
	end

	def inspect_call
		key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
		status = add_to_set(key, params[:call_sid])
		render :json => { :can_accept => (status) ? 1 : 0 }
	end

	def caller_recent_tickets 	
		caller =  current_account.all_users.find_by_id(params[:id]) unless params[:id].blank?
		if caller.present?
			@caller_tickets_count = current_account.tickets.permissible(current_user).requester_active(caller).visible.count
			@caller_tickets = current_account.tickets.permissible(current_user).requester_active(caller).visible.newest(3).find(:all, 
      				:include => [:ticket_status])
		end
    render :partial => 'freshfone/caller/caller_recent_tickets'
	end 

	private
		def load_user_by_phone
			@user = search_user_with_number(params[:PhoneNumber].gsub(/^\+/, ''))
		end

		def call_meta	
	    #Yet to handle the scenario where multiple calls at the same time 
	    #from the same number targeting different groups.
			return if caller.blank?
			call = current_account.freshfone_calls.first( :include => [:freshfone_number], 
							:conditions => {:caller_number_id => caller.id}, :order => "freshfone_calls.id DESC") 

			if call.present?
				{ :number => call.freshfone_number.number_name,
					:ringing_time => call.freshfone_number.ringing_time,
					:transfer_agent => get_transfer_agent(call),
					:group 	=> (call.group.present?) ? call.group.name : "",
					:company_name => (@user.present? && @user.company_name.present?) ? @user.company_name : ""
				}
			end
		end

		def caller 
			@caller ||= current_account.freshfone_callers.find_by_number(params[:PhoneNumber])
		end

		def caller_card
			render_to_string(:partial => 'layouts/shared/freshfone/caller_card.html', :locals => { :user => @user, :caller_location => caller_location } , :format=> :html)
		end

		def caller_location 
			return [caller.city , caller.country].compact.reject{|c| c.empty? }.join(", ") if caller.present?
			GlobalPhone.parse(params[:PhoneNumber]).territory.name 
		end 

		def populate_call_details
			key = ACTIVE_CALL % { :account_id => current_account.id, :call_sid => params[:DialCallSid]}
			@call_options = {}
			call_options = get_key key
			unless call_options.blank?
				@call_options = JSON.parse(call_options)
				params.merge!(@call_options)
				remove_key key
			end
		end

		def force_termination
			if params[:force_termination]
				return empty_twiml if in_progress?
				add_cost_job
				update_call_status unless preview?
				return empty_twiml
			end
		end

		def call_forwarded?
			@call_options["answered_on_mobile"] || params[:direct_dial_number]
		end

		def direct_dialled_call?
			params[:direct_dial_number].present?
		end

		def preview?
			(params[:preview] && params[:preview] == 'true') || false
		end

		def scoper_for_calls
			current_account.freshfone_subaccount.calls
		end
		
		def called_agent_id
			split_client_id(scoper_for_calls.get(params[:DialCallSid]).to) if params[:DialCallSid].present?
		end

		def call_initiator
			@call_initiator ||= Freshfone::CallInitiator.new(params, current_account, current_number, current_call_flow)
		end

		def call_action
			@call_action ||= Freshfone::CallActions.new(params, current_account, current_number)
		end

		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number)
		end

		def empty_twmil_without_render
			Twilio::TwiML::Response.new
		end

		def validate_twilio_request
			@callback_params = params.except(*[:agent, :direct_dial_number, :preview,
							:batch_call, :force_termination, :number_id, :below_safe_threshold, 
							:forward, :transfer_call, :call_back, :source_agent, :target_agent, 
							:outgoing, :group_transfer])
			super
		end

		def get_transfer_agent(call)
			return false unless (call.meta.present? && call.meta.transfer_by_agent.present?)
			user = current_account.users.find_by_id(call.meta.transfer_by_agent) 
			return false unless user.present?
			avatar = view_context.user_avatar(user, :thumb, "preview_pic small circle")
			 {
				:user_id => user.id,
				:user_hover => avatar,
				:user_name => user.name
			}
		end

		def in_progress?
			params[:CallStatus] == 'in-progress'
		end

		def set_abandon_state
			return unless current_call.present? 
			current_call.set_abandon_call(params)
		end
end
