class Auth::SalesforceAuthenticator < Auth::Authenticator

  def self.title
    "salesforce"
  end

  def after_authenticate(params)
    access_token = @omniauth.credentials
    config_params = {
      'app_name' => "#{@app.name}",
      'oauth_token' => "#{access_token.token}",
      'instance_url' => "#{access_token.instance_url}",
      'refresh_token' => "#{access_token.refresh_token}"
    }
    set_redis_keys config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider :salesforce,
                      :setup => lambda { |env|
      strategy = env["omniauth.strategy"]
      strategy.options[:client_id] = Integrations::OAUTH_CONFIG_HASH["salesforce"]["consumer_token"]
      strategy.options[:client_secret] = Integrations::OAUTH_CONFIG_HASH["salesforce"]["consumer_secret"]
    }
  end

  def get_redirect_url
    "#{@portal_url}/integrations/salesforce/new"
  end
end