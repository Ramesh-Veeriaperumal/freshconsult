module TwilioMaster

	#All callback methods requested by Twilio are listed below. 
	#Added request Validation and skipped privelege check for the these methods
	PUBLIC_METHODS = {
		:freshfone => [:voice, :ivr_flow, :voice_fallback, :preview_ivr],
		:call => [:in_call, :status, :direct_dial_success, :call_transfer_success, :external_transfer_success],
		:conference => [:wait, :incoming_agent_wait, :agent_wait, :outgoing_accepted, :connect_incoming_caller, :client_accept, :connect_agent],
		:forward => [:initiate, :complete, :transfer_initiate, :transfer_wait, :transfer_complete,
			:direct_dial_wait, :direct_dial_accept, :direct_dial_connect, :direct_dial_complete, :initiate_custom,
			:initiate_custom_transfer, :process_custom, :process_custom_transfer],
		:hold => [ :initiate, :wait, :unhold, :transfer_unhold, :transfer_fallback_unhold, :quit ],
		:conference_call => [ :status, :in_call, :update_recording ],
		:conference_transfer => [ :transfer_agent_wait, :transfer_source_redirect, :transfer_success ],
		:warm_transfer => [:success, :status, :wait, :quit, :redirect_source_agent, :redirect_customer, :transfer_agent_wait, :join_agent, :initiate_custom_forward, :process_custom_forward],
		:agent_conference => [ :success, :status, :initiate_custom_forward, :process_custom_forward],
		:call_transfer => [:transfer_incoming_call, :transfer_outgoing_call, :transfer_incoming_to_group, 
			:transfer_outgoing_to_group, :transfer_incoming_to_external, :transfer_outgoing_to_external],
		:device => [:record],
		:queue => [:enqueue, :dequeue, :trigger_voicemail, :trigger_non_availability, :hangup, :quit_queue_on_voicemail, :redirect_to_queue],
	:voicemail => [:initiate, :quit_voicemail, :transcribe],
		:usage_triggers => [:notify],
		:ops_notification => [:voice_notification, :status]
	}
	
	CALL_INITIATION_METHODS = {
		:freshfone => [ :voice ],
		:device => [ :record ]
	}

	def self.client
		account_sid = FreshfoneConfig['twilio']['account_sid']
    auth_token = FreshfoneConfig['twilio']['auth_token']
    Twilio::REST::Client.new(account_sid, auth_token)
	end

	def self.account
		self.client.account
	end
end