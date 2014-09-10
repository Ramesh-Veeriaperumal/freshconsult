class Mobile::SettingsController < ApplicationController

  include ApplicationHelper

	def index
		render :json => {:success => true , :notifications_url => MobileConfig['notifications_url'][Rails.env]}
	end

# Mobile devices to fetch admin level settings
  def mobile_pre_loader
    render :json => {ff_feature: current_account.freshfone_account,view_social: can_view_social? , portal_name: current_account.portal_name , portal_id: current_account.id , host_name: current_account.host , user_id: current_user.id }
  end  
	
end
