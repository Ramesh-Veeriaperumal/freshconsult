class OmniauthCallbacksController < ApplicationController

  include Redis::OthersRedis
  include Redis::RedisKeys

  INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

  before_filter :set_native_mobile

  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                     :check_day_pass_usage, :set_locale, :check_session_timeout, only: [:complete, :failure]

  PORTAL_OMINIAUTH_FEATURE_MAPPING = {
    google_login: :google_signin,
    twitter: :twitter_signin,
    facebook: :facebook_signin
  }.freeze

  VALID_TIME_DIFF = 5 * 60 * 1000 # 5 minutes in millies

  def complete
    return failure if portal_login? && (!feature_enabled? || invalid_request?)
    authenticator_class = Auth::Authenticator.get_auth_class(params[:provider])
    authenticator = authenticator_class.new(
      :origin_account => origin_account,
      :current_account => current_account,
      :portal_url => @ignore_build.blank? ? portal_url : nil,
      :app => app,
      :omniauth => @omniauth,
      :user_id => @user_id,
      :falcon_enabled => @falcon_enabled,
      :state_params => @state_params,
      :r_key => @r_key,
      :failed => false
    )
    
    result = authenticator.after_authenticate(params)
    flash[:notice] = result.flash_message if result.flash_message.present?
    render result.render and return if result.render.present?

    return failure if result.failed?
    invalid_nmobile if result.invalid_nmobile.present?
    redirect_to result.redirect_url || root_url(:host => origin_account.host)
  end

  def failure
    if params[:provider] == 'gmail' || 'outlook'
      authenticator_class = Auth::Authenticator.get_auth_class(params[:provider])

      authenticator = authenticator_class.new(
        :origin_account => origin_account,
        :current_account => current_account,
        :portal_url => @ignore_build.blank? ? portal_url : nil,
        :app => app,
        :omniauth => @omniauth,
        :user_id => @user_id,
        :falcon_enabled => @falcon_enabled,
        :state_params => @state_params,
        :r_key => @r_key,
        :failed => true,
        :message => @message
      )
      result = authenticator.after_authenticate(params)
      redirect_to result.redirect_url || root_url(:host => origin_account.host) and return
    else
      port = path = ''
      path = integrations_applications_path
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to portal_url + port + path
    end
  end

  private

  def select_shard(&block)
    load_origin_info if ['complete', 'failure'].include?(params[:action])
    raise ActionController::RoutingError, "Not Found" if (@account_id.nil? and origin_required?) && params[:state].blank?
    if @account_id.present?
      Sharding.select_shard_of(@account_id) do
        yield
      end
    else
      yield
    end
  end

  def load_origin_info
    origin = request.env["omniauth.origin"].present? ? request.env["omniauth.origin"] : params[:origin]
    @omniauth = request.env['omniauth.auth']
    @provider = (@omniauth and @omniauth['provider']) ? @omniauth['provider'] : params[:provider]
    raise ActionController::RoutingError, "Not Found" if (origin.blank? and origin_required?) && params[:state].blank?
    origin = CGI.parse(origin) if origin.present?
    @app_name ||= Integrations::Constants::PROVIDER_TO_APPNAME_MAP["#{@provider}"] if @provider.present?
    assign_state_variables(origin) if params[:state].present?
    assign_default_variables(origin) if origin.present? && origin.has_key?('id')
    @message = params[:message] if params[:message].present?
  end

  def assign_default_variables origin
    @account_id = origin['id'][0].to_i
    @portal_id = origin['portal_id'][0].to_i if origin.has_key?('portal_id')
    @user_id = origin['user_id'][0].to_i if origin.has_key?('user_id')
    @state_params = origin['state_params'][0] if origin.has_key?('state_params')
    @falcon_enabled = origin['falcon_enabled'][0] if origin.has_key?('falcon_enabled')
    @r_key = origin.has_key?('r_key') ? origin['r_key'][0] : params[:r_key]
  end

  def assign_state_variables origin
    @state_params = CGI.parse(URI.decode(params[:state]))
    if @state_params["ignore_build"].present?
      @ignore_build = true
    else
      domain_param = (@state_params["portal_domain"].presence || @state_params["full_domain"].presence )
      return unless domain_param.present?
      @domain = domain_param[0] 
      domain_mapping = DomainMapping.find_by_domain(@domain)
      if domain_mapping.present?
        @account_id =  domain_mapping.account_id
        @portal_id = domain_mapping.portal_id
      end
    end
  end

  def origin_required?
    request.host == INTEGRATION_URL
  end

  def origin_account
    @origin_account ||= @account_id ? Account.find(@account_id) : current_account
  end

  def app
    return unless @app_name
    @app ||= Integrations::Application.find_by_name(@app_name)
  end

  def portal_url
    account = origin_account
    object = @portal_id.present? ? Portal.find(@portal_id) : account
    port = ''
    if object.is_a?(Account)
      @portal_url = "#{object.url_protocol}://#{object.full_domain}"
    elsif object.is_a?(Portal)
      @portal_url = "#{object.url_protocol}://#{object.host}#{port}"
    end
  end

  def invalid_nmobile
    cookies["mobile_access_token"] = { :value => 'customer', :http_only => true } 
  end

  def invalid_request?
    invalid_request = false
    return invalid_request unless origin_account.enable_secure_login_check_enabled?
    return invalid_request if @state_params['identifier'].blank?

    identifier_http_host = JWT.decode(@state_params['identifier'][0], origin_account.provider_login_token).first['domain']
    acc_id_in_token = ShardMapping.lookup_with_domain(identifier_http_host).try(:account_id)
    iat = JWT.decode(@state_params['identifier'][0], origin_account.provider_login_token).first['iat']
    invalid_request = (origin_account.id != acc_id_in_token) || ((Time.now.utc.to_f * 1000).to_i - iat.to_i) > VALID_TIME_DIFF
    invalid_request
  rescue => e
    true
  end

  def feature_enabled?
    origin_account.has_feature?(PORTAL_OMINIAUTH_FEATURE_MAPPING[params[:provider].to_sym])
  end

  def portal_login?
    params[:provider] ? PORTAL_OMINIAUTH_FEATURE_MAPPING.key?(params[:provider].to_sym) : false
  end
end
