class Freshfone::CallController < FreshfoneBaseController
	include Freshfone::FreshfoneUtil
	include Freshfone::CallHistory
	include Freshfone::Presence
	include Freshfone::NumberMethods
	include Freshfone::CallsRedisMethods
	include Freshfone::TicketActions
	include Freshfone::Call::EndCallActions
	include Freshfone::NumberValidator
	
	include Freshfone::Search
	before_filter :load_customer, :only => [:caller_data]
	before_filter :set_native_mobile, :only => [:caller_data]
	before_filter :populate_call_details, :only => [:status]
	before_filter :set_abandon_state, :only => [:status]
	before_filter :force_termination, :only => [:status]
	before_filter :clear_client_calls, :only => [:status]
	before_filter :reset_outgoing_count, :only => [:status]
	before_filter :validate_trial, :only => [:trial_warnings]
	
	skip_after_filter :set_last_active_time, :only => [:caller_data], :unless =>lambda{ params[:outgoing]}

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
          :call_meta => call_meta, :caller_card => caller_card,
          :email => (@user || {})[:email],  :mobile => (@user || {})[:mobile],
          :phone => (@user || {})[:phone]
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
		result = { can_accept: ((status) ? 1 : 0) }
		result[:agent_conference] = agent_conference_details if status
		result[:warm_transfer] = warm_transfer_avatar if warm_transfer_enabled? && status
		render :json => result
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

	def trial_warnings
		respond_to do |format|
			format.json do
				render :json => trial_warnings_meta
			end
		end
	end

  private
    def load_customer
      @user ||= begin
        if ongoing_call.present?
          ongoing_call.customer
        else
          search_customer
        end
      end
    end

		def call_meta
	    #Yet to handle the scenario where multiple calls at the same time 
	    #from the same number targeting different groups.
			return if caller.blank?
			
			if ongoing_call.present?
				call_data = { :number => ongoing_call.freshfone_number.number_name,
											:ringing_time => ongoing_call.freshfone_number.ringing_time,
											:transfer_agent => get_transfer_agent(ongoing_call),
											:group 	=> (ongoing_call.group.present?) ? ongoing_call.group.name : "",
											:company_name => (@user.present? && @user.company_name.present?) ? @user.company_name : "",
										}
        call_data[:agent_conference] = agent_conference_meta(ongoing_call) if agent_conference_launched?
        call_data[:warm_transfer] =  warm_transfer_avatar(ongoing_call) if warm_transfer_enabled?
			end
			call_data
		end

		def caller 
			@caller ||= current_account.freshfone_callers.find_by_number(params[:PhoneNumber])
		end

		def caller_card
			render_to_string(:partial => 'layouts/shared/freshfone/caller_card.html', :locals => { :user => @user, :caller_location => caller_location } , :format=> :html)
		end

		def caller_location 
			return [caller.city , caller.country].compact.reject{|c| c.empty? }.join(", ") if caller.present?
			fetch_country_code(params[:PhoneNumber])
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
   return false unless call.meta.present? && call.meta.transfer_by_agent.present? && call.default?
   user = current_account.users.find_by_id(call.meta.transfer_by_agent)
   return false unless user.present?
   build_avatar(user)
 end

 def agent_conference_meta(call)
   return false unless agent_conference_call?(call)
   return false unless call.agent.present?
   build_avatar(call.agent)
 end

  def warm_transfer_avatar(call = nil)
    transfer_call = warm_transfer_call(call)
    return false unless transfer_call.present? && transfer_call.call.agent.present? && transfer_call.warm_transfer?
    return build_avatar(transfer_call.call.agent).merge!(is_receiver: true)
  end

 def agent_conference_details
   return unless agent_conference_launched?
   conference_call = conference_call_by_sid(params[:call_sid])
   return unless conference_call.present? && conference_call.agent_conference?
   build_avatar(conference_call.call.agent).merge!(is_receiver: true)
 end

 def new_notifications_warm_transfer_call
  current_call.supervisor_controls.warm_transfer_initiated_calls.last if current_call.present?
 end

 def build_avatar(user)
   avatar = view_context.user_avatar(user, :thumb, 'preview_pic small circle')
   { user_id: user.id, user_hover: avatar, user_name: user.name }
 end

 def agent_conference_call?(call)
   @agent_conference_call ||= call.supervisor_controls
                                  .agent_conference_calls(Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
                                  .find_by_supervisor_id(agent.id).present?
 end

 def warm_transfer_call(call = nil)
    return @warm_transfer_call ||= call.supervisor_controls.warm_transfer_initiated_calls
                                       .where(supervisor_id: agent.id).last if call.present?
    @warm_transfer_call ||= new_notifications_warm_transfer_call
 end

 def conference_call_by_sid(sid)
 	  current_account.supervisor_controls.find_by_sid(params[:call_sid])
 end

 def agent_conference_launched?
 	current_account.features?(:agent_conference)
 end

		def in_progress?
			params[:CallStatus] == 'in-progress'
		end

		def set_abandon_state
			return unless current_call.present? 
			current_call.set_abandon_call(params)
		end

		def validate_trial
			return head :no_content unless params[:CallSid].present? && trial?
		end

		def trial_warnings_meta
			return {} if current_call.blank?
			return freshfone_subscription.incoming_trial_warnings if current_call.incoming?
			freshfone_subscription.outgoing_trial_warnings
		end

		def ongoing_call
			@ongoing_call ||= current_account.freshfone_calls.ongoing_by_caller(caller.id).first if caller.present?
		end
end
