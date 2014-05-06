class Freshfone::CallController < FreshfoneBaseController
	include FreshfoneHelper
	include Freshfone::Presence
	include Redis::RedisKeys
	include Redis::IntegrationsRedis
	include Freshfone::TicketActions
	include Freshfone::NumberMethods
	include Freshfone::Queue
	include Freshfone::CallsRedisMethods
	
	before_filter :populate_call_details, :only => [:status]
	before_filter :force_termination, :only => [ :status ]
	before_filter :clear_client_calls, :only => [:status]
	before_filter :handle_batch_calls, :only => [ :status ]
	before_filter :handle_missed_calls, :only => [:status]
	before_filter :handle_transferred_call, :only => [:status]
	after_filter  :check_for_bridged_calls, :only => [:status]
	before_filter :prepare_message_for_publish,  :only => [:in_call]
	before_filter :set_dial_call_sid, :only => [:in_call, :call_transfer_success, :direct_dial_success]
	
	def in_call
		update_presence_and_publish_call(params, @message) if params[:agent].present?
		update_call
		return empty_twiml
	end
	
	def direct_dial_success
		update_call
		publish_live_call(params)
		return empty_twiml
	end

	def call_transfer_success
		update_agent_presence(params[:source_agent]) unless params[:call_back].to_bool
		update_call
		return empty_twiml
	end

	def status
		begin
			call_forwarded? ? handle_forwarded_calls : normal_end_call
		rescue Exception => e
			notify_error({:ErrorUrl => e.message})
			return empty_twiml
		ensure
			add_cost_job unless call_transferred?
		end
	end

	def inspect_call
		key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
		status = add_to_set(key, params[:call_sid])
		render :json => { :can_accept => (status) ? 1 : 0 }
	end

	private
		def handle_forwarded_calls
			unpublish_live_call(params)
			update_call
			empty_twiml
		ensure
			update_user_presence if params[:direct_dial_number].blank?
		end

		def normal_end_call
			params[:agent] ||= called_agent_id
			update_call
			unpublish_live_call(params)
			empty_twiml
		end

		def handle_batch_calls
			return (render :xml => call_initiator.connect_caller_to_agent(@available_agents)) if batch_call?
			clear_batch_key if params[:batch_call]
		end

		def handle_missed_calls
			update_call
			render :xml =>  call_initiator.non_availability if missed_call?
		end

		def check_for_bridged_calls
			bridge_queued_call(params[:agent]) if call_forwarded? and params[:direct_dial_number].blank?
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

		def call_transferred?
			@transfer_key = FRESHFONE_TRANSFER_LOG % { :account_id => current_account.id, 
											 :call_sid => (params[:ParentCallSid] || params[:CallSid]) }
			@transferred_calls ||= get_key(@transfer_key)
			@transferred_calls.present? || params[:call_back].present? 
			# call_back param used while source agent reject the transfered call
		end
		
		def force_termination
			if params[:force_termination]
				add_cost_job
				update_call_status unless preview?
				return empty_twiml
			end
		end

		def transfer_complete?
			transferred_calls = JSON.parse(@transferred_calls)
			called_agent_id = current_call.user_id.to_s
			if transferred_calls.last == called_agent_id
    		remove_key @transfer_key
    		return true
    	end
		end

		def clear_client_calls
			key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
			remove_from_set(key, params[:DialCallSid]) if params[:DialCallSid]
		end

		def add_cost_job
			Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
			Rails.logger.debug "FreshfoneJob for sid : #{params[:CallSid]} :: dsid : #{params[:DialCallSid]}"
		end

		def add_transfer_cost_job
			add_cost_job if transfer_complete?
		end

		def call_forwarded?
			@call_options["answered_on_mobile"] || params[:direct_dial_number]
		end

		def missed_call?
			#Redirect to voicemail on missed incoming calls and non-outgoing calls
			Freshfone::CallInitiator::VOICEMAIL_TRIGGERS.include?(params[:DialCallStatus]) and 
					!current_call.outgoing? and !call_transferred?
		end

		def prepare_message_for_publish
    	@message = {:agent => params[:agent]}
    	@message.merge!({:answered_on_mobile => true}) if params[:forward].present?
    end
		
		def cost_params
			{ :account_id => current_account.id, 
				:call_sid => params[:CallSid], 
				:dial_call_sid => params[:DialCallSid],
				:call => (current_call || {})[:id],
				:call_forwarded => call_forwarded?,
				:billing_type => preview? ? Freshfone::OtherCharge::ACTION_TYPE_HASH[:ivr_preview] : nil,
				:transfer => call_transferred?,
				:number_id => params[:number_id],
				:below_safe_threshold => params[:below_safe_threshold]
			}
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

		def batch_call?
			missed_call? && params[:batch_call] && batch_agents_ids.present? && batch_agents_online.present?
		end
		
		def clear_batch_key
			key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => params[:CallSid] }
			remove_key(key)
		end
		
		def batch_agents_ids
			@batch_agents_ids ||= begin
				key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => params[:CallSid] }
				batch_agents_ids = get_key(key)
				remove_key(key)
				batch_agents_ids.blank? ? batch_agents_ids : JSON::parse(batch_agents_ids)
			end
		end

		def batch_agents_online
			@available_agents = current_account.freshfone_users.online_agents.find_all_by_id(batch_agents_ids)
		end

		def preview?
			(params[:preview] && params[:preview] == 'true') || false
		end

		def validate_twilio_request
			@callback_params = params.except(*[:agent, :direct_dial_number, :preview,
							:batch_call, :force_termination, :number_id, :below_safe_threshold, :forward, :transfer_call, :call_back, :source_agent, :target_agent, :outgoing])
			super
		end

		def update_agent_presence(agent)
			return if agent.blank?
			agent = current_account.users.find_by_id(agent)
			update_freshfone_presence(agent, Freshfone::User::PRESENCE[:online])
			publish_freshfone_presence(agent)
			publish_success_of_call_transfer(agent, is_successful_transfer?)
		end

		def handle_transferred_call
			if call_transferred?
				update_call
				dial_to_source_agent and return	empty_twmil_without_render if should_call_back_to_agent?
				add_transfer_cost_job
				update_agent_presence(params[:source_agent])
				unpublish_live_call(params)
				return empty_twmil_without_render
			end
		end

		def should_call_back_to_agent?
			!(params[:CallStatus] == 'completed' || params[:DialCallStatus] == 'completed'  || params[:call_back].to_bool)
		end

		def is_successful_transfer?
		 params[:DialCallStatus] == "in-progress"
		end

		def set_dial_call_sid
			params.merge!({:DialCallSid => params[:CallSid], :DialCallStatus => params[:CallStatus]})
		end

		def dial_to_source_agent
			params.merge!({:outgoing => params[:outgoing].to_bool})
			update_transfer_log(params[:source_agent])
			render :xml => call_initiator.make_transfer_to_agent(params[:source_agent], true)
		end

		def empty_twmil_without_render
			Twilio::TwiML::Response.new
		end
end