class Mobile::AutomationsController < ApplicationController

	include HelpdeskAccessMethods
	def index
		render :json => accessible_elements(current_account.all_scn_automations, query_hash('VARule', 'va_rules', '')).to_json
	end
end