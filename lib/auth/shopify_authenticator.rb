class Auth::ShopifyAuthenticator < Auth::Authenticator

  def self.title
    'shopify'
  end

  def after_authenticate(params)
    access_token = @omniauth.credentials
    config_params = {
      'refresh_token' => "#{access_token.refresh_token}",
      'oauth_token' => "#{access_token.token}",
      'shop_name' => params[:shop]
    }

    set_redis_keys config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider :shopify, Integrations::OAUTH_CONFIG_HASH["shopify"]["consumer_token"],
                        Integrations::OAUTH_CONFIG_HASH["shopify"]["consumer_secret"],
                      :setup => lambda {|env| params = Rack::Utils.parse_query(env['QUERY_STRING'])
                        env['omniauth.strategy'].options[:client_options][:site] = "https://#{params['shop']}" }

  end

  def get_redirect_url
    "#{@portal_url}/integrations/marketplace/shopify/create"
  end

end
