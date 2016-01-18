class Mobile::FreshfoneController < ApplicationController

	before_filter :set_native_mobile, :only => [:can_accept_incoming_calls]

	def numbers
		render :json => {:freshfone_numbers => current_account.freshfone_numbers.map(&:as_numbers_mjson),:group_numbers => current_account.freshfone_numbers.accessible_freshfone_numbers(current_user).map(&:as_numbers_mjson)}
	end

	# return true if incoming is allowed via desktop app
	def can_accept_incoming_calls
		accept_incoming = false
		respond_to do |format|
			format.js {}
			format.nmobile {
				freshfone_user = current_user.freshfone_user
				unless freshfone_user.nil?
					accept_incoming = current_user.freshfone_user_online? && !freshfone_user.available_on_phone 
				end
				render :json => {:accept_incoming => accept_incoming}
			}
		end
	end
	
end
