class Auth::GoogleContactsAuthenticator < Auth::Authenticator

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
    set_redis_keys(config_params, 300)
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_contacts"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_contacts"]["consumer_secret"],
      :scope        => "https://www.google.com/m8/feeds https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile",
      :prompt       => "select_account consent", #consent is needed to get the refresh_token otherwise we don't get it!
      :access_type  => "offline",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_contacts/callback",
      :name         => "google_contacts")
  end

  private

    def get_redirect_url
      "#{@portal_url}/integrations/google_accounts/new"
    end

end
