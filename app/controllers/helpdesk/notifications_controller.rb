class Helpdesk::NotificationsController < ApplicationController

	include Notifications::MessageBroker

  prepend_before_filter :silence_logging, :only => :index
  after_filter   :revoke_logging, :only => :index
	
	def index
		begin
			render :json => subscribe.to_json
		rescue Exception => e
			NewRelic::Agent.notice_error(e,{:description => "Error occoured in getting notification"})
			render :json => []
		end
	end

end