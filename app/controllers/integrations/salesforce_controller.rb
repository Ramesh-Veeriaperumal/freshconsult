class Integrations::SalesforceController < ApplicationController
	include Integrations::Oauth2Helper
	def get_access_token
		Rails.logger.debug "Getting new access token from Salesforce  " + params.inspect
		app_id = Integrations::Application.find(:first, :conditions => {:name => 'salesforce'}).id
		salesforce_app = Integrations::InstalledApplication.find(:first, :conditions => {:account_id => current_account, :application_id => app_id})
		refresh_token = salesforce_app[:configs][:inputs]['refresh_token']
		access_token = get_oauth2_access_token(refresh_token)
		salesforce_app[:configs][:inputs]['oauth_token'] = access_token.token
		salesforce_app.save!
		render :json => {:access_token => access_token.token}
	end
end
