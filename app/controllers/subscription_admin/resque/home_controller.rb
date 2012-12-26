class SubscriptionAdmin::Resque::HomeController < ApplicationController
	include AdminControllerMethods
	layout "resque_admin"

	def index
	end

	def show
		redirect_to :index
	end

end	