class Helpdesk::NotificationsController < ApplicationController
  skip_before_filter :check_privilege
	include Notifications::MessageBroker

	
	def log_file_path
    @log_file_path = "#{Rails.root}/log/notification.log"      
  end 
  
  def log_file_format
    @log_file_format = "controller=#{request.parameters[:controller]}, action=#{request.parameters[:action]}, url=#{request.url}, params=#{params.inspect}"      
  end 

	def index
		begin
		rescue Exception => e
			NewRelic::Agent.notice_error(e,{:description => "Error occoured in getting notification"})
			render :json => []
		end
	end

end