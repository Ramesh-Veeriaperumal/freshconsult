module TwilioMaster

	#All callback methods requested by Twilio are listed below. 
	#Added request Validation and skipped privelege check for the these methods
	PUBLIC_METHODS = {
		:freshfone => [:voice, :ivr_flow, :voice_fallback],
		:call => [:forward, :status, :direct_dial_success],
		:call_transfer => [:transfer_incoming_call, :transfer_outgoing_call],
		:device => [:record],
		:queue => [:enqueue, :dequeue, :trigger_voicemail, :hangup, :quit_queue_on_voicemail],
		:voicemail => [:quit_voicemail]
	}

	def self.client
		account_sid = AppConfig['twilio']['account_sid']
    auth_token = AppConfig['twilio']['auth_token']
    Twilio::REST::Client.new(account_sid, auth_token)
	end

	def self.account
		self.client.account
	end
end