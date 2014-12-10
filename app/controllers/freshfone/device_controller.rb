class Freshfone::DeviceController < FreshfoneBaseController
	include Freshfone::FreshfoneHelper
	include Freshfone::NumberMethods
	include Freshfone::Presence
	include Redis::RedisKeys
	include Redis::IntegrationsRedis

	before_filter :save_recorded_greeting, :only => [:record]
	
	def record
		twiml = Twilio::TwiML::Response.new do |r|
			r.Say "Preparing your recorded message. Make sure you save the settings upon completion.", 
				:voice => current_number.voice_type
		end
		render :xml => twiml.text
	ensure
		Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, 
											{ :account_id => current_account.id, 
												:call_sid => params[:CallSid],
												:billing_type => Freshfone::OtherCharge::ACTION_TYPE_HASH[:message_record],
												:number_id => current_number.id })
	end

	def recorded_greeting
		url = get_key("FRESHFONE:RECORDING:#{current_account.id}:#{default_client}")
		remove_key("FRESHFONE:RECORDING:#{current_account.id}:#{default_client}")
		render :json => { :url => url }
	end

	private
		def save_recorded_greeting
			set_key("FRESHFONE:RECORDING:#{current_account.id}:#{params[:agent]}", params[:RecordingUrl])
		end

		def validate_twilio_request
			@callback_params = params.except(*[:agent, :number_id])
			super
		end

end