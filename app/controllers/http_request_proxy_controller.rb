class HttpRequestProxyController < ApplicationController
  include Integrations::AppsUtil
  
  skip_before_filter :check_privilege
  before_filter :authenticated_agent_check 
  before_filter :populate_server_password

  def fetch
    httpRequestProxy = HttpRequestProxy.new
    http_resp = httpRequestProxy.fetch(params, request);
    response.headers.merge!(http_resp.delete('x-headers')) if http_resp['x-headers'].present?
    render http_resp
  end

  private
    def populate_server_password
      if params[:use_server_password].present?
        installed_app = current_account.installed_applications.with_name(params[:app_name]).first
        if params[:app_name] == "icontact"
          config = File.join(Rails.root, 'config', 'integrations_config.yml')
          key_hash = (YAML::load_file config)["icontact"]
          params[:custom_auth_header] = {"API-Version" => "2.0", "API-AppId" => key_hash["app_id"] , "API-Username" => installed_app.configs_username, "API-Password" => installed_app.configsdecrypt_password}
        elsif params[:app_name] == "surveymonkey" and params[:domain]=='api.surveymonkey.net'
          params[:custom_auth_header] = {"Authorization" => "Bearer #{installed_app.configs[:inputs]['oauth_token']}"}
        elsif params[:app_name] == "harvest"
          harvest_auth(installed_app)
        else
          params[:password] = installed_app.configsdecrypt_password
        end
      end
    end

    def harvest_auth(installed_app)
      user_credential = installed_app.user_credentials.find_by_user_id(current_user)
      return if user_credential.blank?
      params[:username] = user_credential.auth_info[:username]
      params[:password] = Base64.decode64(user_credential.auth_info[:password])
    end

    def authenticated_agent_check
      render :status => 401 if current_user.blank? || current_user.agent.blank?
    end
end
