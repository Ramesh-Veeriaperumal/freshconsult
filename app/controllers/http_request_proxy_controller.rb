class HttpRequestProxyController < ApplicationController

  include Integrations::AppsUtil
  include Integrations::Constants
  include Redis::IntegrationsRedis

  skip_before_filter :check_privilege
  before_filter :authenticated_agent_check 
  before_filter :populate_server_password
  before_filter :verify_domain
  before_filter :populate_additional_headers

  DOMAIN_WHITELIST = "INTEGRATION_WHITELISTED_DOMAINS"
  def fetch
    httpRequestProxy = HttpRequestProxy.new
    http_resp = httpRequestProxy.fetch(params, request);
    if request.method.upcase == 'GET'
      Rails.logger.error "8fdb249d32ae991ca3969c27cbe927c9db4d4bca AccountID: #{current_account.id} PARAMS: #{params.inspect}"
    end
    response.headers.merge!(http_resp.delete('x-headers')) if http_resp['x-headers'].present?
    render http_resp
  end

  private
    def populate_server_password  
      if params[:use_server_password].present?
        installed_app = current_account.installed_applications.with_name(params[:app_name]).first
        if params[:app_name] == "icontact"
          params[:custom_auth_header] = { "API-Version" => "2.0", "API-AppId" => Integrations::ICONTACT_APP_ID,
           "API-Username" => installed_app.configs_username,
           "API-Password" => installed_app.configsdecrypt_password }
        elsif params[:app_name] == APP_NAMES[:surveymonkey] and params[:domain]=='api.surveymonkey.net'
          render :status => :unauthorized and return unless current_user.privilege?(:admin_tasks)
          params[:custom_auth_header] = {"Authorization" => "Bearer #{installed_app.configs[:inputs]['oauth_token']}"}
        elsif params[:app_name] == APP_NAMES[:shopify]
          params[:custom_auth_header] = {'X-Shopify-Access-Token' => "#{installed_app.configs[:inputs]['oauth_token']}"}
        elsif params[:app_name] == APP_NAMES[:harvest]
          harvest_auth(installed_app)
        elsif params[:app_name] == APP_NAMES[:infusionsoft]
          params[:rest_url] += "#{installed_app.configs[:inputs]['oauth_token']}" 

        elsif params[:app_name] == APP_NAMES[:pivotal_tracker]
          params[:custom_auth_header] = {"X-Trackertoken" => "#{installed_app.configs[:inputs]['api_key']}" }
        elsif params[:app_name] == APP_NAMES[:seoshop]
          params[:username] = "#{installed_app.configs[:inputs]['api_key']}"
          params[:password] = "#{installed_app.configs[:inputs]['api_secret']}"
        elsif params[:app_name] == APP_NAMES[:freshbooks]
          params[:username] = "#{installed_app.configs[:inputs]['api_key']}"
          params[:password] = "x"
        elsif params[:build_auth_header].present?
          params[:custom_auth_header] = { "Authorization" => "#{params[:token_type]} #{installed_app.configs[:inputs]['oauth_token']}" }
        elsif params[:app_name] == APP_NAMES[:sugarcrm]
          params[:domain] = installed_app.configs_domain
          @domain_verified = true
          company_name = ""
          if params[:company_id].present?
            company_name = spl_char_replace current_account.companies.find(params[:company_id]).name
          end
    		  params[:body] = params[:body] % { :SESSION_ID => installed_app.configs[:inputs]['session_id'], :company_name => company_name}
        elsif params[:app_name] == "czentrix" #adding this as a hack in here. ideally it should not be here.
          params[:domain] = "#{request.protocol}#{installed_app.configs[:inputs][:host_ip]}"
          @domain_verified = true
        elsif params[:app_name] == "jira"
          params[:domain] = installed_app.configs_domain
          params[:password] = installed_app.configsdecrypt_password
          @domain_verified = true
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
      render :status => 401 if current_user.blank? || !current_user.agent?
    end

    def verify_domain
      return if @domain_verified
      begin
        parsed_url = URI.parse(params[:domain])
        parsed_url = URI.parse("#{request.protocol}#{params[:domain]}") if parsed_url.scheme.nil?
        host = parsed_url.host
        host = "#{host}:#{parsed_url.port}" if [80, 443].exclude?(parsed_url.port)
        whitelisted = value_in_set?(DOMAIN_WHITELIST, host)
        unless whitelisted
          main_domain_regex = /^(?:(?>[a-z0-9-]*\.)+?|)([a-z0-9-]+\.(?>[a-z]*(?>\.[a-z]{2})?))$/i
          main_domain = parsed_url.host.gsub(main_domain_regex, '\1')
          main_domain = "#{main_domain}:#{parsed_url.port}" if [80, 443].exclude?(parsed_url.port)
          whitelisted = value_in_set?(DOMAIN_WHITELIST, main_domain)
        end

        unless whitelisted
          Rails.logger.error "4cfc55925b4585a66ad2265b90c97fd8ddb67b37WHITELIST #{parsed_url.host} is not in the whitelist for account id: #{current_account.id}"
          render :status => 404
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :url => params[:domain] }})
        render :status => 404
      end
    end

    def populate_additional_headers
      return if params["additional_custom_header"].nil?
      begin
        custom_headers = JSON.parse(params["additional_custom_header"]) 
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error setting custom headers"}}) 
      end
      unless custom_headers.nil?
        params[:custom_auth_header] = (params[:custom_auth_header] || {}).merge(custom_headers)
      end
    end
end
