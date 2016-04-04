class OmniauthCallbacksController < ApplicationController

  INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                     :check_day_pass_usage, :set_locale, :only => [:complete, :failure]

  def complete
    authenticator_class = Auth::Authenticator.get_auth_class(params[:provider])

    authenticator = authenticator_class.new(
      :origin_account => origin_account,
      :current_account => current_account,
      :portal_url => portal_url,
      :app => app,
      :omniauth => @omniauth,
    )

    result = authenticator.after_authenticate(params)
    flash[:notice] = result.flash_message if result.flash_message.present?
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
    raise ActionController::RoutingError, "Not Found" if @account_id.nil? and origin_required?
    Sharding.select_shard_of(@account_id || request.host) do
      yield
    end
  end

  def load_origin_info
    origin = request.env["omniauth.origin"]
    @omniauth = request.env['omniauth.auth']
    @provider = (@omniauth and @omniauth['provider']) ? @omniauth['provider'] : params[:provider]

    raise ActionController::RoutingError, "Not Found" if origin.blank? and origin_required?

    origin = CGI.parse(origin)
    @app_name ||= Integrations::Constants::APP_NAMES[@provider.to_sym] if @provider.present?

    if origin.has_key?('id')
      @account_id = origin['id'][0].to_i
      @portal_id = origin['portal_id'][0].to_i if origin.has_key?('portal_id')
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
  end

end
