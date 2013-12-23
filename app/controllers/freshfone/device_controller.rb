class Freshfone::DeviceController < FreshfoneBaseController
	include FreshfoneHelper
	include Freshfone::Presence
	include Redis::RedisKeys
	include Redis::IntegrationsRedis

	before_filter :save_recorded_greeting, :only => [:record]
	
	def record
		twiml = Twilio::TwiML::Response.new do |r|
			r.Say "Preparing your recorded message. Make sure you save your messages upon completion."
		end
		render :xml => twiml.text
	ensure
		Rails.logger.debug "Added Freshfone Cost Calculation Job for Recorded Message sid::::: #{params[:CallSid]}"
		Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, 
											{ :account_id => current_account.id, 
												:call_sid => params[:CallSid],
												:dont_update_record => true })
	end

	def recorded_greeting
		render :json => {
			:url => get_key("FRESHFONE:RECORDING:#{current_account.id}:#{default_client}")
		}
	end

	private
		def save_recorded_greeting
			set_key("FRESHFONE:RECORDING:#{current_account.id}:#{params[:agent]}", params[:RecordingUrl])
		end

		def validate_twilio_request
			@callback_params = params.except(:agent)
			super
		end

end