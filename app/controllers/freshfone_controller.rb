class FreshfoneController < FreshfoneBaseController
	include FreshfoneHelper
	include Freshfone::TicketActions
	include Freshfone::NumberMethods

	before_filter :indian_number_incoming_fix, :only => [:voice, :ivr_flow]

	def voice
		render :xml => current_call_flow.resolve_request
	end
	
	def ivr_flow
		render :xml => current_call_flow.trigger_ivr_flow
	end	
	alias_method :preview_ivr, :ivr_flow

	def voice_fallback
		notify_error params
		empty_twiml
	end
	
	def dashboard_stats
		@freshfone_users = freshfone_user_scoper.online_agents_with_avatar.map do |freshfone_user|
			{ :available_agents_name => freshfone_user.name, 
				:available_agents_avatar => user_avatar(freshfone_user.user),
				:id => freshfone_user.user_id
			}
		end
		
		@active_calls = get_count_from_integ_redis_set(NEW_CALL % {:account_id => current_account.id})
		respond_to do |format|
			format.js 
		end
	end

	def credit_balance
		render :json => { :credit_balance => ( !current_account.freshfone_credit.below_calling_threshold? ) }
	end

	private
		
		def freshfone_user_scoper
			current_account.freshfone_users
		end
		
		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number, current_user)
		end

		def indian_number_incoming_fix
			#Temp fix suggested by Twilio to truncate +1 country code in incoming calls from India
			from = params[:From]
			params[:From] = from.gsub(/^\+1/, "+") if 
						params[:FromCountry] == "US" and from.starts_with?("+1") and from.length > 12
		end

		def validate_twilio_request
			@callback_params = params.except :menu_id
			super
		end

end