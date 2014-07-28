class Mobile::SettingsController < ApplicationController

	def index
		render :json => {:success => true , :notifications_url => MobileConfig['notifications_url'][Rails.env]}
	end
	
end
