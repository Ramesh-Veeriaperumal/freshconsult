class OmniauthCallbacksController < ApplicationController

  INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

  before_filter :set_native_mobile

  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                     :check_day_pass_usage, :set_locale, :only => [:complete, :failure]

  def complete
    authenticator_class = Auth::Authenticator.get_auth_class(params[:provider])

    authenticator = authenticator_class.new(
      :origin_account => origin_account,
      :current_account => current_account,
      :portal_url => @ignore_build.blank? ? portal_url : nil,
      :app => app,
      :omniauth => @omniauth,
      :user_id => @user_id
    )
    
    result = authenticator.after_authenticate(params)
    flash[:notice] = result.flash_message if result.flash_message.present?
    render result.render and return if result.render.present?
    return failure if result.failed?
    redirect_to result.redirect_url || root_url(:host => origin_account.host)
  end

  def failure
    port = ''
    path = ''
    path = integrations_applications_path
    flash[:notice] = t(:'flash.g_app.authentication_failed')
    redirect_to portal_url + port + path
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
    origin = request.env["omniauth.origin"]
    @omniauth = request.env['omniauth.auth']
    @provider = (@omniauth and @omniauth['provider']) ? @omniauth['provider'] : params[:provider]
    raise ActionController::RoutingError, "Not Found" if (origin.blank? and origin_required?) && params[:state].blank?
    origin = CGI.parse(origin) if origin.present?
    @app_name ||= Integrations::Constants::PROVIDER_TO_APPNAME_MAP["#{@provider}"] if @provider.present?

    if origin.present? && origin.has_key?('id')
      assign_default_variables(origin)
    elsif params[:state].present?
      assign_state_variables(origin)
    end
  end

  def assign_default_variables origin
    @account_id = origin['id'][0].to_i
    @portal_id = origin['portal_id'][0].to_i if origin.has_key?('portal_id')
    @user_id = origin['user_id'][0].to_i if origin.has_key?('user_id')
  end

  def assign_state_variables origin
    state_params = CGI.parse(URI.decode(params[:state]))
    if state_params["ignore_build"].present?
      @ignore_build = true
    else
      @domain = (state_params["portal_domain"].presence || state_params["full_domain"].presence)[0]
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
    portal = (@portal_id ? Portal.find(@portal_id) : account.main_portal)
    port = ''
    @portal_url = "#{portal.url_protocol}://#{portal.host}#{port}"
    @portal_url = "http://localhost:3000" if Rails.env.eql? "development"
  end

end
