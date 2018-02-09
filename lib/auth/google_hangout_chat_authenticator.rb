class GoogleHangoutChatAuthenticator < Auth::Authenticator
  SCOPE = 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/admin.directory.user.alias.readonly https://www.googleapis.com/auth/admin.directory.user.readonly'.freeze

  def after_authenticate(params)
    config_params = {
        'app_name'      => @app.name,
        'refresh_token' => @omniauth.credentials.refresh_token,
        'oauth_token'   => @omniauth.credentials.token,
        "info"          => {
            "email"       => @omniauth['info']['email'],
            "first_name"  => @omniauth['info']['first_name'],
            "last_name"   => @omniauth['info']['last_name'],
            "name"        => @omniauth['info']['name']
        }
    }
    set_redis_keys config_params, 3600
    @result.redirect_url = fetch_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
        :google_oauth2,
        Integrations::OAUTH_CONFIG_HASH["google_hangout_chat"]["consumer_token"],
        Integrations::OAUTH_CONFIG_HASH["google_hangout_chat"]["consumer_secret"],
        :scope        => SCOPE,
        :prompt       => "select_account consent", #we'll get refresh_token only when consent is included!
        :access_type  => "offline",
        :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_hangout_chat/callback",
        :name         => "google_hangout_chat")
  end

  private

  def fetch_redirect_url
    url = 'integrations/google_hangout_chat/install'
    @falcon_enabled == 'true' ? "#{@portal_url}/a/#{url}" : "#{@portal_url}/#{url}"
  end

end