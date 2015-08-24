module Freshfone::Presence
	include Freshfone::NodeEvents
	
	def update_freshfone_presence(user, status)
		freshfone_user(user).set_presence(status)
	end

	def update_presence_and_publish_call(params, message=nil)
		user = current_user || current_account.users.find_by_id(params[:agent])
		update_freshfone_presence(user, Freshfone::User::PRESENCE[:busy])
	end

	def update
		render :json => { :status => update_freshfone_presence(current_user, params[:status]) }
	end
	
	def freshfone_user(user)
		user.freshfone_user || user.build_freshfone_user({ :account => user.account })
	end

end
