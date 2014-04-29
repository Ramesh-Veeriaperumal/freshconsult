class SubscriptionAdmin::Resque::HomeController < ApplicationController
	include AdminControllerMethods
	layout "resque_admin"

	def index
	end

	def show
		redirect_to :index
	end

	def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:manage_admin))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 

end	