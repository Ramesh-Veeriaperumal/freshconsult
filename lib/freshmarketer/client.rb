class Freshmarketer::Client
  include Freshmarketer::Constants

  attr_accessor :response_code, :response_data

  def link_account(data, is_create = true)
    invoke_call do
      account_details = is_create ? create_account(data) : associate_account(data)
      acc_id = account_details['account_id']
      auth_token = account_details['authtoken']
      cdn_script = account_details['cdnscript'].html_safe
      app_url = account_details['app_url'].html_safe
      integrate_url = account_details['integrate_url'].html_safe
      set_freshmarketer_hash(acc_id, auth_token, cdn_script, app_url, integrate_url)
      { acc_id: acc_id, auth_token: auth_token, cdn_script: cdn_script, app_url: app_url, integrate_url: integrate_url }
    end
  end

  def unlink_account
    clear_freshmarketer_hash
  end

  def enable_integration
    invoke_call do
      response = request(basic_query_params, ENABLE_INTEGRATION_URL, :post)
      response['enableintegration']['result']
    end
  end

  def disable_integration
    invoke_call do
      response = request(basic_query_params, DISABLE_INTEGRATION_URL, :post)
      response['disableintegration']['result'] ? '' : false
    end
  end

  def fetch_cdn_script
    invoke_call do
      response = request(basic_query_params, GET_CDN_SCRIPT_URL, :get)
      response['cdnscript']['result']
    end
  end

  def recent_sessions(filter)
    invoke_call do
      query_params = basic_query_params.merge(id: filter, limit: SESSIONS_LIMIT, sortOrder: false)
      response = request(query_params, GET_SESSIONS_URL, :get)
      response['sessions']
    end
  end

  def experiment
    invoke_call do
      response = request(basic_query_params, GET_EXPERIMENT_URL, :get)
      response['expdetails']
    end
  end

  def session(session_id)
    invoke_call do
      response = request(basic_query_params, format(GET_SESSION_URL, session_id: session_id), :get)
      response['{sessionid}']
    end
  end

  # create_account, associate_account & remove_account has to be accessed via wrapper method as it modifies DB

  def create_account(email)
    payload = { email_id: email, domain: account_domain }
    response = request(account_setup_params, CREATE_ACCOUNT_URL, :post, payload)
    response['createsraccount']
  end

  def enable_predictive_support(exp_id = freshmarketer_acc_id)
    query_param = {
      access_key: auth_token,
      account_id: exp_id
    }
    invoke_call do
      response = request(query_param, ENABLE_PREDICTIVE_SUPPORT_URL, :put)
      response['enablepredictivesupport']['result']
    end
  end

  def disable_predictive_support(exp_id = freshmarketer_acc_id)
    query_param = {
      access_key: auth_token,
      account_id: exp_id
    }
    invoke_call do
      response = request(query_param, DISABLE_PREDICTIVE_SUPPORT_URL, :put)
      response['disablepredictivesupport']['result']
    end
  end

  def create_experiment(domain)
    query_param = {
      access_key: auth_token,
      enable_predictive_support: true
    }
    invoke_call do
      response = request(query_param, CREATE_EXPERIMENT, :post, domain: domain)
      {
        exp_id: response['create_experiment']['result'],
        status: true
      }
    end
  end

  def enable_predictive_integration(exp_id)
    query_param = {
      access_key: auth_token,
      account_id: exp_id
    }
    invoke_call do
      response = request(query_param, ENABLE_INTEGRATION_URL, :post)
      response['status_code'] == 200
    end
  end

  def disable_predictive_integration(exp_id)
    query_param = {
      access_key: auth_token,
      account_id: exp_id
    }
    invoke_call do
      response = request(query_param, DISABLE_INTEGRATION_URL, :post)
      response['disableintegration']['result']
    end
  end

  def associate_account(token)
    payload = { token: token, domain: account_domain }
    response = request(account_setup_params, ASSOCIATE_ACCOUNT_URL, :post, payload)
    response['associatesraccount']
  end

  def remove_account
    response = request(basic_query_params, REMOVE_ACCOUNT_URL, :post)
    response['Status']
  end

  private

    def invoke_call
      @response_data = yield
    rescue InternalServerErrorException
      @response_code = :internal_server_error
    rescue BadRequestException => e
      @response_code = ERROR_CODE_MAPPING[e.message]
    rescue ForbiddenRequestException => e
      @response_code = ERROR_CODE_MAPPING[e.message]
    rescue ResourceConflictException => e
      @response_code = ERROR_CODE_MAPPING[e.message]
    end

    def request(params, path, request_type, payload = {})
      # Not logging params and payload as it contains token and accout data
      Rails.logger.info "Freshmarketer API Request ::: path: #{path} request_type: #{request_type}"
      connection = freshmarketer_connection
      response = begin
        case request_type
        when :get
          connection.get do |req|
            req.url "#{FreshmarketerConfig['api_endpoint']}#{path}"
            req.params = params
          end
        when :post
          connection.post do |req|
            req.url "#{FreshmarketerConfig['api_endpoint']}#{path}"
            req.params = params
            req.body = payload
          end
        when :put
          connection.put do |req|
            req.url "#{FreshmarketerConfig['api_endpoint']}#{path}"
            req.params = params
            req.body = payload
          end
        end
      end
      handle_failure(response)
    end

    def freshmarketer_connection
      connection = Faraday.new(url: CGI.escape(FreshmarketerConfig['api_endpoint'])) do |conn|
        conn.request :json
        conn.request :url_encoded
        conn.adapter Faraday.default_adapter
      end
      connection.headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
      connection
    end

    def handle_failure(response)
      response_msg = JSON.parse(response.body)
      if success_response_codes.include?(response.status)
        @response_code = :ok
      else
        Rails.logger.error "Freshmarketer API Error Response :: #{response}"
        case response_msg['messagecode']
        when 'E403IT', 'E409IC', 'E403IS', 'E403SR'
          raise ForbiddenRequestException, response_msg['messagecode']
        when 'E400EA'
          raise ResourceConflictException, response_msg['messagecode']
        when 'E400IE', 'E400II', 'E400ID', 'E404IR', 'E409IU'
          raise BadRequestException, response_msg['messagecode']
        else
          raise InternalServerErrorException, 'Something went wrong'
        end
      end
      response_msg
    end

    def success_response_codes
      [200, 204]
    end

    def basic_query_params
      { access_key: auth_token, account_id: freshmarketer_acc_id }
    end

    def account_setup_params
      { access_key: access_key }
    end

    def access_key
      FreshmarketerConfig['access_key']
    end

    def auth_token
      Account.current.account_additional_settings.freshmarketer_auth_token
    end

    def freshmarketer_acc_id
      Account.current.account_additional_settings.freshmarketer_acc_id
    end

    def set_freshmarketer_hash(acc_id, auth_token, cdn_script, app_url, integrate_url)
      account_additional_settings = Account.current.account_additional_settings
      freshmarketer_acct_info = { acc_id: acc_id, auth_token: auth_token, cdn_script: cdn_script, app_url: app_url, integrate_url: integrate_url }
      if account_additional_settings.present? && account_additional_settings.additional_settings.present?
        account_additional_settings.additional_settings[:freshmarketer] = freshmarketer_acct_info
        account_additional_settings.save
      else
        additional_settings = { freshmarketer: freshmarketer_acct_info }
        account_additional_settings.update_attributes(additional_settings: additional_settings)
      end
    end

    def clear_freshmarketer_hash
      account_additional_settings = Account.current.account_additional_settings
      if account_additional_settings.present? && account_additional_settings.additional_settings[:freshmarketer].present?
        unlink_freshmarketer_from_widget if account_additional_settings.additional_settings[:widget_predictive_support].present?
        account_additional_settings.additional_settings = account_additional_settings.additional_settings.except(:freshmarketer, :widget_predictive_support)
        account_additional_settings.save
      end
    end

    # return base domain if account has custom domain enabled
    def account_domain
      domain_name = Account.current.host
      domain_name.include?(AppConfig['base_domain'][Rails.env]) ? domain_name : domain_name.partition('.').last
    end

    def unlink_freshmarketer_from_widget
      Account.current.help_widgets.active.each do |widget|
        next unless widget.settings[:components][:predictive_support]

        widget.settings[:components][:predictive_support] = false
        widget.settings.delete(:freshmarketer)
        widget.save
      end
    end

    class BadRequestException < StandardError
    end

    class ForbiddenRequestException < StandardError
    end

    class InternalServerErrorException < StandardError
    end

    class ResourceConflictException < StandardError
    end
end
