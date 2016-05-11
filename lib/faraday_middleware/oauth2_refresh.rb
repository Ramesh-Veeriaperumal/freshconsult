module FaradayMiddleware

  class RefreshTokenLimitReached < Faraday::Error::ClientError
    attr_reader :response

    def initialize(response)
      super "Refresh token limit exceeded; last response status: #{response.status}"
      @response = response
    end
  end

  class Oauth2Refresh < Faraday::Middleware
    AUTH_HEADER = "Authorization".freeze

    RETRY_LIMIT = 1

    ENV_TO_CLEAR = Set.new [:status, :response, :response_headers]
    
    def initialize(app=nil, options = {})
      super(app)
      @options = options
      @access_token = options[:oauth2_access_token]
      @new_token = nil
    end

    def call(env)
      check_and_refresh_token(env, retry_limit)
    end

    def check_and_refresh_token(env,limits)
      req_body = env[:body]
      response = @app.call env
      response.on_complete do |response_env|
        if token_expired?(response)
          raise RefreshTokenLimitReached, response if limits.zero?
          current_account = Account.current
          app = Integrations::Application.where(:name => "salesforce").first
          installed_app = current_account.installed_applications.where(:application_id => app.id).first
          if current_account.features?(:cloud_elements_crm_sync) and installed_app.try(:configs_element_token)          
            element_instance = service_obj(installed_app, {}, installed_app.configs_element_instance_id).receive(:get_element_instance)
            @new_token =  element_instance["configuration"]["oauth.user.token"]
          else
            @new_token = @access_token.refresh!.token
          end
          new_request_env = update_env(response_env, req_body, @new_token)
          response = check_and_refresh_token(new_request_env,limits-1)
        end
      end
      response.env[:new_token] = @new_token unless (@new_token.nil? || (@access_token.token.eql? @new_token))
      response
    end

    def retry_limit
      @options.fetch(:limit, RETRY_LIMIT)
    end

    def token_expired?(response)
      response.status == 401
    end

    def update_env(env, req_body, token)
      env[:request_headers][AUTH_HEADER] = "OAuth #{token}"
      env[:body] = req_body
      ENV_TO_CLEAR.each {|key| env.delete key }
      env
    end

    def service_obj installed_app, payload ={}, element_token
      metadata = {:user_agent => "Freshdesk", :element_instance_id => element_token }
      IntegrationServices::Services::CloudElementsService.new( installed_app, payload, metadata)
    end

  end
end