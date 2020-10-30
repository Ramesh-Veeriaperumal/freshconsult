class Auth::GoogleLoginAuthenticator < Auth::Authenticator
  include GoogleLoginHelper
  include Helpdesk::Permission::User
  include ActionController::Helpers
  include Freshid::ControllerMethods

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
    return google_login_freshid_redirect if freshid_agent?(domain_user.email, @origin_account)
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
        unless env["PATH_INFO"].split("/")[3] == "callback"
          raise "Google Signin Feature is not enabled for this account." unless google_signin_enabled?(env["HTTP_HOST"])
          env['omniauth.strategy'].options[:state] = construct_state_params(env) 
        end
      },
      :scope => "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :access_type => "online",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_login/callback",
      :name => "google_login")
  end

  private

    def google_signin_enabled?(full_domain)
        flag = false
        Rails.logger.info "Google Authenticator - Full domain = #{full_domain.inspect}"
        Sharding.select_shard_of(full_domain) do
          account =  Account.find_by_full_domain(full_domain) || Portal.find_by_portal_url(full_domain).account
          account.make_current
          flag = account.features?(:google_signin)
        end
        flag
    end
    def construct_state_params env
      env['rack.session']["_csrf_token"] ||= SecureRandom.base64(32)
      csrf_token = Base64.encode64(env['rack.session']["_csrf_token"])
      account_id = ShardMapping.lookup_with_domain(env['HTTP_HOST']).try(:account_id)
      ecrypted_msg = get_ecrypted_msg(account_id, env['HTTP_HOST'])
      "portal_domain%3D#{env['HTTP_HOST']}%26identifier%3D#{ecrypted_msg}%26at%3D#{csrf_token}"
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

    def google_login_freshid_redirect
      account = Account.current
      url_options_with_protocol = { host: account.host, protocol: account.url_protocol }
      authorize_callback_url = Rails.application.routes.url_helpers.freshid_authorize_callback_url(url_options_with_protocol)
      logout_url = Rails.application.routes.url_helpers.freshid_logout_url(url_options_with_protocol)
      @result.redirect_url = account.freshid_org_v2_enabled? ? Freshid::V2::UrlGenerator.login_url(authorize_callback_url) : Freshid::Config.login_url(authorize_callback_url, logout_url)
      @result
    end

end
