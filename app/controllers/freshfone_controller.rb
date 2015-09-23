class FreshfoneController < FreshfoneBaseController
	include Freshfone::FreshfoneUtil
	include Freshfone::CallHistory
	include Freshfone::TicketActions
	include Freshfone::NumberMethods
	include Freshfone::CallValidator
	include Freshfone::Response

	attr_accessor :freshfone_users
	before_filter :indian_number_incoming_fix, :only => [:voice, :ivr_flow]
	before_filter :set_native_mobile, :only => :create_ticket
	before_filter :apply_conference_mode, :only => [:voice, :ivr_flow]
		
	def voice
		render :xml => current_call_flow.resolve_request
	end

	def voice_conference
		current_call = current_account.freshfone_calls.find_by_id(params[:caller_sid])
		begin
			initiator = Freshfone::Initiator.new(params, current_account, current_number, current_user)
			response = initiator.resolve_call
			render :xml => response
		rescue Exception => e # Spreadheet L 5
			Rails.logger.error "Error in voice_conference for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call if current_call.present?
      empty_twiml and return
		end
	end
	
	def ivr_flow
		render :xml => current_call_flow.trigger_ivr_flow
	end	
	alias_method :preview_ivr, :ivr_flow

	def ivr_flow_conference
		initiator = Freshfone::Initiator.new(params, current_account, current_number, current_user)
		response = initiator.resolve_ivr
		render :xml => response
	end


	def voice_fallback
		notify_error params
		empty_twiml
	end
	
	def dashboard_stats
		@available_agents = freshfone_user_scoper.online_agents.count		
		@active_calls = freshfone_user_scoper.busy_agents.count
		render :json => {:available_agents => @available_agents, :active_calls => @active_calls}
	end

  def dial_check
	 	render :json => asserted_status(validate_outgoing)
  end

	private

    def call_answered
      response = { :status => :answered }
      current_call.agent.present? ? response.merge!(:answered_by => current_call.agent.name) : response
    end
		
		def freshfone_user_scoper
			current_account.freshfone_users
		end
		
		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number, current_user)
		end

		def indian_number_incoming_fix
			#Temp fix suggested by Twilio to truncate +1 country code in incoming calls from India
			from = params[:From]
			 if params[:FromCountry] == "US" and from.starts_with?("+1") and from.length > 12
	 			params[:From] = from.gsub(/^\+1/, "+")
			 	reset_caller_params
			 end
		end

		def reset_caller_params
			params[:FromCountry] = country_from_global(params[:From])
			params[:FromState] = ""
			params[:ToCity] = ""
		end

		def apply_conference_mode
			if current_account.features?(:freshfone_conference)
				if params[:action] == "voice"
					voice_conference
				elsif params[:action] == "ivr_flow"
					ivr_flow_conference
				end
			end
		end

		def validate_twilio_request
			if params[:action] == 'preview_ivr'
				@callback_params = params.except(*[:menu_id, :id, :preview])
			else
				@callback_params = params.except(*[:menu_id, :caller_sid, :agent_id, :leg_type, :transfer_call, 
					:external_transfer, :external_number, :round_robin_call, :forward_call, :forward])
			end
			super
		end

end
