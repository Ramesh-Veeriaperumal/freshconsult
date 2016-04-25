class Auth::GoogleGadgetAuthenticator < Auth::Authenticator
  include Integrations::GoogleAppsHelper
  include Integrations::GoogleGadgetHelper

  
  def after_authenticate(params)
    return non_hd_account if google_domain.blank?
    state_params = params["state"].present? ? CGI.parse(URI.decode(params["state"])) : nil
    account_id = account_from_google_domain
    if state_params.present? && state_params["gv_id"].present? #Individual agent OAuth2 and viewer id link case
      @origin_account.make_current
      link_google_viewer_id(state_params)
    elsif account_id.present?
      Sharding.select_shard_of(account_id) do
        sso(account_id, params)
      end
    else
      onboard
    end
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_gadget_oauth2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_gadget_oauth2"]["consumer_secret"],
      :setup        => lambda { |env|
        construct_setup_key(env)
      },
      :scope        => "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :prompt       => "select_account consent",
      :access_type  => "online",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_gadget/callback",
      :name         => "google_gadget")
  end

  private

    def construct_setup_key env
      unless env["PATH_INFO"].split("/")[3] == "callback"
        override_env(env)
      end
      env
    end

    def override_env(env)
      query = Rack::Utils.parse_query(env['QUERY_STRING'])
      if query.blank? # Gadget Onbording, Gadget SSO case
        env['omniauth.strategy'].options[:state] = "ignore_build%3Dtrue"
      elsif query["origin"].present? # Gadget Gvid to agent google_viewer_id linking case.
        env['omniauth.strategy'].options[:state] = state_for_viewer_id_link(query)
        env['omniauth.strategy'].options[:prompt] = ""
      end
    end

    def link_google_viewer_id(state_params)
      google_gadget_auth(state_params, email, uid)
      if @gadget_error.present?
        @result.render = { :text => @notice } 
      else
        @result.render = { :text => I18n.t('flash.gmail_gadgets.gvid_success') }
      end
    end

    def account_full_domain google_domain
      account_id = account_id_from_google_domain(google_domain)
      account = nil
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
      end
      account.present? ? account.full_domain : nil
    end

    def state_for_viewer_id_link query
      parse_query = CGI.parse(query["origin"])
      google_domain = parse_query["domain"][0]
      gv_id = parse_query["t"][0]
      domain = account_full_domain(google_domain)
      "full_domain%3D" + domain + "%26gv_id%3D" + gv_id
    end

end
