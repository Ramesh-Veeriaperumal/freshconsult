class Auth::GoogleLoginAuthenticator < Auth::Authenticator
  include GoogleLoginHelper

  def after_authenticate(params)
    @origin_account.make_current
    begin
      verify_domain_user(@origin_account, nmobile?(params))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.debug "Error while Google Login SSO-> #{@origin_account.id} \n #{e.backtrace}"
      @result.flash_message = I18n.t(:'flash.g_app.domain_restriction')
      @result.redirect_url = "#{@portal_url}"
      return @result
    end

    random_key = SecureRandom.hex
    set_redis_for_sso(random_key)
    @result.redirect_url = construct_redirect_url(@origin_account, domain, random_key)
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_secret"],
      :setup => lambda { |env|
        env['omniauth.strategy'].options[:state] = construct_state_params(env) unless env["PATH_INFO"].split("/")[3] == "callback"
      },
      :scope => "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :prompt => "select_account",
      :access_type => "online",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_login/callback",
      :name => "google_login")
  end

  private
    def construct_state_params env
      "portal_domain%3D#{env['HTTP_HOST']}"
    end

end
