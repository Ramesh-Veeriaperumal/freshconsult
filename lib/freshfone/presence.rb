module Freshfone::Presence
	include Freshfone::NodeEvents
	
	def update_freshfone_presence(user, status)
		freshfone_user(user).set_presence(status)
	end

	def update_presence_and_publish_call(params, message=nil)
		user = current_user || current_account.users.find_by_id(params[:agent])
		add_active_call_params_to_redis(params, message) if 
			!fresfone_conference? && params[:CallSid].present? && !params[:dont_update_call_count]
		update_freshfone_presence(user, Freshfone::User::PRESENCE[:busy])
	end

	def update
		render :json => { :status => update_freshfone_presence(current_user, params[:status]) }
	end
	
	def freshfone_user(user)
		user.freshfone_user || user.build_freshfone_user({ :account => user.account })
	end

	private
		def fresfone_conference?
			current_account.features? :freshfone_conference
		end

end
