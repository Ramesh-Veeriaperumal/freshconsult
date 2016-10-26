class Mobile::FreshfoneController < FreshfoneBaseController
include Freshfone::CallValidator
include Freshfone::Response

	before_filter :set_native_mobile, :only => [:can_accept_incoming_calls, :is_ringing]

	def numbers
		render json: {freshfone_numbers: current_account.freshfone_numbers.map(&:as_numbers_mjson),
			group_numbers: current_account.freshfone_numbers.accessible_freshfone_numbers(current_user).map(&:as_numbers_mjson),
			outgoing_call_access: asserted_status(validate_outgoing), acw_timeout: acw_timeout}
	end

	# return acw timeout in seconds if acw is enabled else null
	def acw_timeout
		return current_account.freshfone_account.acw_timeout.to_i.minutes if phone_acw_enabled?
	end

	# return true if a After call wrapping up feature enabled
	def phone_acw_enabled?
		current_account.features? :freshfone_acw
	end

	# return true if a call with given call_id is ringing
	def is_ringing
		call = current_account.freshfone_calls.find(params[:call_id])
		respond_to do |format|
			format.js {}
			format.nmobile {
				render :json => {ringing: call.default?}
			}
		end
	end

	# return true if incoming is allowed via desktop app
	def can_accept_incoming_calls
		accept_incoming = false
		respond_to do |format|
			format.js {}
			format.nmobile {
				freshfone_user = current_user.freshfone_user
				unless freshfone_user.nil?
					accept_incoming = freshfone_user.get_incoming_preference?
				end
				render :json => {:accept_incoming => accept_incoming}
			}
		end
	end

end
