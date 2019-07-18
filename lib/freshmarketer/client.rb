class Freshmarketer::Client
  include Freshmarketer::Constants

  attr_accessor :response_code, :response_data

  def link_account(data, type = :create, experiment_domain = nil)
    invoke_call do
      account_details = case type
                        when 'create'
                          create_account(data, experiment_domain)
                        when 'associate_using_domain'
                          associate_using_domain(data, experiment_domain)
                        when 'associate'
                          associate_using_api_key(data)
                        end
      return if response_code != :ok

      # Here acc_id is experiment_id
      skip_acc_id = experiment_domain.present? && experiment_domain != account_domain
      acc_id = skip_acc_id ? nil : account_details['account_id']
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

  def enable_integration(experiment_id = freshmarketer_acc_id)
    query_params = {
      access_key: auth_token,
      account_id: experiment_id
    }
    invoke_call do
      response = request(query_params, ENABLE_INTEGRATION_URL, :post)
      response['enableintegration']['result']
    end
  end

  def disable_integration(experiment_id = freshmarketer_acc_id)
    query_params = {
      access_key: auth_token,
      account_id: experiment_id
    }
    invoke_call do
      response = request(query_params, DISABLE_INTEGRATION_URL, :post)
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

  def experiment(experiment_id = freshmarketer_acc_id)
    query_params = {
      access_key: auth_token,
      account_id: experiment_id
    }
    invoke_call do
      response = request(query_params, GET_EXPERIMENT_URL, :get)
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

  def create_account(email, domain = nil)
    payload = { email_id: email, domain: domain || account_domain }
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

  def domains(email = User.current.email)
    query_param = {
      access_key: access_key,
      email_id: email
    }
    invoke_call do
      request(query_param, GET_DOMAINS_URL, :get)
    end
  end

  def create_experiment(domain = account_domain, frustration_tracking = false)
    query_param = {
      access_key: auth_token,
      enable_predictive_support: frustration_tracking
    }
    invoke_call do
      request(query_param, CREATE_EXPERIMENT, :post, domain: domain)
    end
    return if response_code != :ok

    experiment_id = response_data['create_experiment']['result']
    update_experiment_id(experiment_id) if domain == account_domain
    experiment_id
  end

  def associate_using_domain(current_domain, experiment_domain = nil)
    payload = {
      email_id: User.current.email,
      account_domain: current_domain,
      domain: experiment_domain
    }
    associate_account(payload)
  end

  def associate_using_api_key(api_key)
    payload = {
      token: api_key,
      domain: account_domain
    }
    associate_account(payload)
  end

  def associate_account(payload)
    response = request(account_setup_params, ASSOCIATE_ACCOUNT_URL, :post, payload)
    response['associatesraccount']
  end

  def remove_account
    response = request(basic_query_params, REMOVE_ACCOUNT_URL, :post)
    response['Status']
  end

  def enable_session_replay
    exp_id = create_experiment
    update_experiment_id(exp_id) if exp_id
  end

  private

    def invoke_call
      @response_data = yield
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
        error_code = response_msg['messagecode']
        case error_code
        when 'E403IT', 'E409IC', 'E403IS', 'E403SR'
          @response_code = ERROR_CODE_MAPPING[error_code]
        when 'E400EA'
          @response_code = ERROR_CODE_MAPPING[error_code]
        when 'E400IE', 'E400II', 'E400ID', 'E404IR', 'E409IU'
          @response_code = ERROR_CODE_MAPPING[error_code]
        else
          @response_code = :internal_server_error
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

    def account_additional_settings
      @account_additional_settings ||= Account.current.account_additional_settings_from_cache
    end

    def auth_token
      account_additional_settings.freshmarketer_auth_token
    end

    def freshmarketer_acc_id
      account_additional_settings.freshmarketer_acc_id
    end

    def update_experiment_id(exp_id)
      account_additional_settings.additional_settings[:freshmarketer][:acc_id] = exp_id
      account_additional_settings.save
    end

    def set_freshmarketer_hash(acc_id, auth_token, cdn_script, app_url, integrate_url)
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
        next unless widget.settings[:components] && widget.settings[:components].key?(:predictive_support)

        widget.settings[:components].delete(:predictive_support)
        widget.settings[:predictive_support].delete(:domain_list)
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
