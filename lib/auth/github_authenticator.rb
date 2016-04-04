class Auth::GithubAuthenticator < Auth::Authenticator

  def self.title
    "github"
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
    omniauth.provider :github,
                      :setup => lambda { |env|
      strategy = env["omniauth.strategy"]
      strategy.options[:client_id] = Integrations::OAUTH_CONFIG_HASH["github"]["consumer_token"]
      strategy.options[:client_secret] = Integrations::OAUTH_CONFIG_HASH["github"]["consumer_secret"]
    },
      :scope => "user,repo"
  end

  def get_redirect_url
    "#{@portal_url}/integrations/github/new"
  end
end
