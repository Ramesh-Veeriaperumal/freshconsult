class Integrations::QuickbooksController < ApplicationController
include Integrations::OauthHelper


	def refresh_access_token
		begin
			app_name = Integrations::Constants::APP_NAMES[:quickbooks]
			
			Rails.logger.debug "Getting new access token from #{app_name}  " + params.inspect
			
			app = Integrations::Application.find_by_name(app_name)
			inst_app = current_account.installed_applications.find_by_application_id(app.id)
			
			access_token = get_quickbooks_access_token
			
			if (access_token.token)
				inst_app[:configs][:inputs]['oauth_token'] = access_token.token
				inst_app[:configs][:inputs]['oauth_token_secret'] = access_token.secret
				inst_app[:configs][:inputs]['token_renewal_date'] = Time.now + Integrations::Quickbooks::Constant::TOKEN_RENEWAL_DAYS.days
				inst_app.save
			end
			
			render :json => {:access_token => access_token.token}
		rescue Exception => e
			Rails.logger.error "Error refreshing access token from #{app_name}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			render :json => {:error=> "#{e}"}
		end
	end

	def render_success
		flash[:notice] = t(:'flash.application.install.success')
		render :template => "/integrations/applications/quickbooks_install_success", :layout => "remote_configurations"
	end

	private
		def get_quickbooks_access_token
	      headers = {
	        'Accept' => 'application/json',
	        'Content-Type' => 'application/json'
	      }

	      response = get_oauth1_response({
	      	:app_name => Integrations::Constants::APP_NAMES[:quickbooks],
	      	:method => :get,
	      	:url => Integrations::Quickbooks::Constant::ACCESS_TOKEN_RENEWAL_URI,
	      	:body => nil,
	      	:headers => headers
	      })
	      response_body = response.body
	      response_body = Hash.from_xml(response_body) if (response_body.include? 'xml')

	      if (response_body["ReconnectResponse"]["ErrorCode"])
	        Rails.logger.error "Error getting access token from quickbooks. " + response_body["ReconnectResponse"]["ErrorCode"] + ' - ' + response_body["ReconnectResponse"]["ErrorMessage"]
	        access_token = OAuth::AccessToken.new({}, nil, nil)
	      else
	        access_token = OAuth::AccessToken.new({}, response_body["ReconnectResponse"]["OAuthToken"], response_body["ReconnectResponse"]["OAuthTokenSecret"])
	      end

	      return access_token
	    end

end
