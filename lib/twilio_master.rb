module TwilioMaster

	#All callback methods requested by Twilio are listed below. 
	#Added request Validation and skipped privelege check for the these methods
	PUBLIC_METHODS = {
		:freshfone => [:voice, :ivr_flow, :voice_fallback, :preview_ivr],
		:call => [:in_call, :status, :direct_dial_success, :call_transfer_success],
		:call_transfer => [:transfer_incoming_call, :transfer_outgoing_call],
		:device => [:record],
		:queue => [:enqueue, :dequeue, :trigger_voicemail, :trigger_non_availability, :hangup, :quit_queue_on_voicemail],
		:voicemail => [:quit_voicemail],
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