class Helpdesk::NotificationsController < ApplicationController
  skip_before_filter :check_privilege
	include Notifications::MessageBroker

	
	def index
		begin
			render :json => subscribe.to_json
		rescue Exception => e
			NewRelic::Agent.notice_error(e,{:description => "Error occoured in getting notification"})
			render :json => []
		end
	end

end