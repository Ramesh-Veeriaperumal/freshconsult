class HttpRequestProxyController < ApplicationController
  include Integrations::AppsUtil
  before_filter :authenticated_agent_check 
  before_filter :populate_server_password

  def fetch
    httpRequestProxy = HttpRequestProxy.new
    render httpRequestProxy.fetch(params, request);
  end

  private
  	def populate_server_password
  		if !params[:use_server_password].blank? and params[:use_server_password] == 'true'
  			password = get_password_for_app(params[:app_name], current_account)
  			params[:password] = password
  		end
  	end
  
    def authenticated_agent_check
      render :status => 401 if current_user.blank? || current_user.agent.blank?
    end
end
