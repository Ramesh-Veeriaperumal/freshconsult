class Freshfone::CallController < FreshfoneBaseController
	include FreshfoneHelper
	include Freshfone::Presence
	include Redis::RedisKeys
	include Redis::IntegrationsRedis
	include Freshfone::TicketActions
	include Freshfone::NumberMethods
	include Freshfone::Queue
	
	before_filter :populate_call_details, :only => [:status]
	before_filter :force_termination, :only => [ :status ]
	before_filter :clear_client_calls, :only => [:status]
	before_filter :prepare_message_for_publish,  :only => [:forward]
	before_filter :handle_batch_calls, :only => [ :status ]
	before_filter :handle_missed_calls, :only => [:status]
	after_filter  :check_for_bridged_calls, :only => [:status]
	
	def forward
    update_presence_and_publish_call(params, @message)
    return empty_twiml
  end
	
	def direct_dial_success
		publish_live_call(params)
		return empty_twiml
	end

	def status
		begin
			return ivr_call_end if ivr?
			call_forwarded? ? handle_forwarded_calls : normal_end_call
		rescue Exception => e
			notify_error({:ErrorUrl => e.message})
			return empty_twiml
		ensure
			call_transferred? ? add_transfer_cost_job : add_cost_job
		end
	end

	def handle_missed_calls
		update_call
		render :xml =>  call_initiator.initiate_voicemail if missed_call?
	end

	def inspect_call
		key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
		status = integ_set_members(key).include?(params[:call_sid])
		add_to_set(key, params[:call_sid]) unless status
		render :json => { :can_accept => status }
	end

	private
		def handle_forwarded_calls
			unpublish_live_call(params)
			build_ticket
			update_call
			empty_twiml
		ensure
			update_user_presence if params[:direct_dial_number].blank?
		end

		def handle_batch_calls
			return (render :xml => call_initiator.connect_caller_to_agent(@available_agents)) if batch_call?
			clear_batch_key if params[:batch_call]
		end

		def check_for_bridged_calls
			bridge_queued_call(params[:agent]) if 
							call_forwarded? and params[:direct_dial_number].blank?
		end

		def populate_call_details
			key = ACTIVE_CALL % {:call_sid => params[:DialCallSid]}
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
			@transferred_calls.present?
		end
		
		def force_termination
			unless params[:force_termination].blank?
				add_cost_job
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
			remove_from_set(key, params[:DialCallSid]) if integ_set_members(key).include?(params[:DialCallSid])
		end

		def add_cost_job
			Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
			Rails.logger.debug "Added FreshfoneJob for call sid::::: #{params[:CallSid]} :: transferred : #{call_transferred?}
				::#{params[:DialCallSid]} :: ivr: #{ivr?} :: call_forwarded: #{call_forwarded?} :: call: #{(current_call || {})[:id]}"
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
      @message = {:agent => params[:agent], :answered_on_mobile => true}
    end
		
		def normal_end_call
			params[:agent] ||= called_agent_id
			update_call
			unpublish_live_call(params)
			empty_twiml
		end

		def cost_params
			{ :account_id => current_account.id, 
				:call_sid => params[:CallSid], 
				:dial_call_sid => params[:DialCallSid],
				:call => (current_call || {})[:id],
				:call_forwarded => call_forwarded?,
				:ivr => ivr?,
				:dont_update_record => params[:preview],
				:transfer => call_transferred?
			}
		end

		def ivr?
			params[:ivr_status] || false
		end

		def ivr_call_end
			set_current_call(call_action.register_incoming_call) if params[:preview].blank?
			empty_twiml
		end

		def scoper_for_calls
			current_account.freshfone_subaccount.calls
		end
		
		def called_agent_id
			split_client_id(scoper_for_calls.get(params[:DialCallSid]).to) if params[:DialCallSid].present?
		end

		def call_initiator
			@call_initiator ||= Freshfone::CallInitiator.new(params, current_account, current_number)
		end

		def call_action
			@call_action ||= Freshfone::CallActions.new(params, current_account, current_number)
		end

		def validate_twilio_request
			@callback_params = params.except(*[:agent, :direct_dial_number, :ivr_status, :preview, :batch_call, :force_termination])
			super
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
end