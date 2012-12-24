class Integrations::OauthUtilController < ApplicationController
include Integrations::OauthHelper
	def get_access_token
			begin
				Rails.logger.debug "Getting new access token from Salesforce  " + params.inspect
				app_id = Integrations::Application.find(:first, :conditions => {:name => params[:provider]}).id
				salesforce_app = Integrations::InstalledApplication.find(:first, :conditions => {:account_id => current_account, :application_id => app_id})
				refresh_token = salesforce_app[:configs][:inputs]['refresh_token']
				access_token = get_oauth2_access_token(refresh_token)
				salesforce_app[:configs][:inputs]['oauth_token'] = access_token.token
				salesforce_app.save!
				render :json => {:access_token => access_token.token}
			rescue Exception => e
				Rails.logger.error "Error getting access token from Salesforce. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
				render :json => {:error=> "#{e}"}
			end
	end
end
