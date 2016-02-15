class Auth::SlackAuthenticator < Auth::Authenticator

  def self.title
    "slack"
  end

  def after_authenticate(params)
    access_token = @omniauth.credentials
    config_params = {
      'app_name' => "#{@app.name}",
      'oauth_token' => "#{access_token.token}"
    }
    set_redis_keys config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(:slack, Integrations::OAUTH_CONFIG_HASH["slack"]["consumer_token"],
                      Integrations::OAUTH_CONFIG_HASH["slack"]["consumer_secret"])
  end

  def get_redirect_url
    "#{@portal_url}/integrations/slack_v2/new"
  end
end