module Freshfone::CallHistory

	def update_call
		return if current_call.blank?
		current_call.update_status(params.merge({ :called_agent => called_agent })).save
	end
	
	def current_call
		@current_call ||= ( current_call_by_id || current_call_by_filter )
	end

	def set_current_call(call)
		@current_call = call if call.present?
	end

	
	private
		# Find current_call
		def called_agent
			# && params[:DialCallSid]
			agent_scoper.find_by_id(params[:agent]) if current_call.can_log_agent? && params[:agent].present? 
		end

		def freshfone_calls_scoper
			current_account.freshfone_calls
		end
	
		def current_call_by_id
			freshfone_calls_scoper.find_by_id(params[:id]) if params[:id].present?
		end
	
		def current_call_by_filter
			freshfone_calls_scoper.filter_call(params[:CallSid]) if params[:CallSid].present?
		end

		def agent_scoper
			current_account.users.technicians.visible
		end

end