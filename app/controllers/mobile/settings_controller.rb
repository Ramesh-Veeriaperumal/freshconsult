class Mobile::SettingsController < ApplicationController
  include ApplicationHelper

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:deliver_activation_instructions]

	def index
		render :json => {:success => true , :notifications_url => MobileConfig['notifications_url'][Rails.env]}
	end

# Mobile devices to fetch admin level settings
  def mobile_pre_loader
    render :json => {ff_feature: current_account.freshfone_account, view_social: can_view_social? && handles_associated? , portal_name: current_account.portal_name, portal_id: current_account.id, host_name: current_account.host, user_id: current_user.id }
  end

  def deliver_activation_instructions
  	current_user = current_account.users.find_by_email(params[:email]) if params.has_key?(:email)
    if current_user.nil?
      render :json => {result: false}
    else
      current_user.deliver_admin_activation
      render :json => {result: true}
    end
  end  
	
end
