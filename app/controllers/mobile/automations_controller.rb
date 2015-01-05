class Mobile::AutomationsController < ApplicationController
	def index
		render :json => current_account.all_scn_automations.to_json
	end
end