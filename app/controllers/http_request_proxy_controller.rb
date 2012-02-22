class HttpRequestProxyController < ApplicationController
  include Integrations::AppsUtil
  before_filter :populate_server_password, :only => [:fetch]
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
end
