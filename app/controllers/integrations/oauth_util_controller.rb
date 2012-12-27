class Integrations::OauthUtilController < ApplicationController
include Integrations::OauthHelper
before_filter :require_user 
	def get_access_token
			begin
				Rails.logger.debug "Getting new access token from #{params[:provider]}  #{params.inspect}"
				app_id = Integrations::Application.find(:first, :conditions => {:name => params[:provider]}).id
				oauth_app = Integrations::InstalledApplication.find(:first, :conditions => {:account_id => current_account, :application_id => app_id})
				refresh_token = oauth_app[:configs][:inputs]['refresh_token']
				access_token = get_oauth2_access_token(params[:provider], refresh_token)
				oauth_app[:configs][:inputs]['oauth_token'] = access_token.token
				oauth_app.save!
				render :json => {:access_token => access_token.token}
			rescue Exception => e
				Rails.logger.error "Error getting access token from #{params[:provider]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
				render :json => {:error=> "#{e}"}
			end
	end
end
