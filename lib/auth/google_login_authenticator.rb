class Auth::GoogleLoginAuthenticator < Auth::Authenticator
  include GoogleLoginHelper
  include Helpdesk::Permission::User

  def after_authenticate(params)
    @origin_account.make_current
    native_mobile_flag = nmobile?(params)
    begin
      domain_user = verify_domain_user(@origin_account, native_mobile_flag, {restricted_helpdesk_login: true})
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.debug "Error while Google Login SSO-> #{@origin_account.id} \n #{e.backtrace}"
      @result.flash_message = I18n.t(:'flash.g_app.domain_restriction')
      @result.redirect_url = "#{@portal_url}"
      return @result
    end
    return google_login_invalid_redirect if domain_user.blank?
    random_key = SecureRandom.hex
    set_redis_for_sso(random_key)
    domain_arg = domain
    @result.redirect_url = redirect_url(@origin_account, domain_arg, random_key, native_mobile_flag)
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
      csrf_token = Base64.encode64(env['rack.session']["_csrf_token"])
      "portal_domain%3D#{env['HTTP_HOST']}%26at%3D#{csrf_token}"
    end

    def redirect_url(account, domain_arg, random_key, native_mobile_flag)
      protocol = construct_protocol(account, native_mobile_flag)
      protocol + "://" + sso_login_path(domain_arg) + construct_params(domain_arg, random_key) + "&at=#{csrf_token_from_state_params}"
    end

    def sso_login_path domain_arg
      domain_arg + (Rails.env.development? ? ":3000" : "") + "/sso/portal_google_sso"
    end

    def csrf_token_from_state_params
      @state_params["at"].present? ? @state_params["at"][0] : nil
    end

    def google_login_invalid_redirect
      @result.redirect_url = "#{@portal_url}/support/login?restricted_helpdesk_login_fail=true"
      @result.invalid_nmobile = true
      @result
    end

end
