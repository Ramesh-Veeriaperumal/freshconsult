class Integrations::OauthUtilController < ApplicationController
include Integrations::OauthHelper
	def get_access_token
			begin
				app_name = params[:app_name]
				
				Rails.logger.debug "Getting new access token from #{app_name}  " + params.inspect
				
				app = Integrations::Application.find_by_name(app_name)
				inst_app = current_account.installed_applications.find_by_application_id(app.id)
				
				## FETCH "REFRESH TOKEN"
					if(app.user_specific_auth?)
						user_credential = inst_app.user_credentials.find_by_user_id(current_user.id)
						refresh_token = user_credential.auth_info['refresh_token']
					else
						refresh_token = inst_app[:configs][:inputs]['refresh_token']
					end
				
				## REFRESH THE "ACCESS TOKEN" USING THE "REFRESH TOKEN"
					access_token = get_oauth2_access_token(app.oauth_provider, refresh_token, app_name)
				
				## STORE THE NEW "ACCESS TOKEN" IN DATABASE.
					if(app.user_specific_auth?)
						user_credential.auth_info.merge!({'oauth_token' => access_token.token})
						user_credential.save
					else
						inst_app[:configs][:inputs]['oauth_token'] = access_token.token
						inst_app.save
					end
				
				render :json => {:access_token => access_token.token}
			rescue Exception => e
				Rails.logger.error "Error getting access token from #{app_name}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
				render :json => {:error=> "#{e}"}
			end
	end

end
