class Mobile::NotificationsController < ApplicationController

	include Redis::RedisKeys
	include Redis::MobileRedis

	def register_mobile_notification
		message = {
			:registration_key => params[:registration_key],
			:device_os => params[:device_os],
			:notification_types => params[:notification_types].to_json,
     		:account_id => current_account.id,
			:user_id => current_user.id,
			:api_version => params[:api_version].blank? ? "V1" : params[:api_version],
			:secret => current_user.mobile_jwt_secret
    	}
		message.merge! ({:clean_up => true}) if params[:clean_up].present?
		message.merge! ({:new_registration => true}) if params[:new_registration].present?
		puts "DEBUG :: add_to_mobile_reg_queue : message : #{message}"
		puts "DEBUG :: agent ? #{current_user.inspect}"
		count = publish_to_channel MOBILE_NOTIFICATION_REGISTRATION_CHANNEL, message.to_json
		if count>0
			render :json => {:success => true}.to_json
		else
			render :json => {:success => false}.to_json
		end
	end
end
