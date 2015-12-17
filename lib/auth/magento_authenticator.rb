class Auth::MagentoAuthenticator < Auth::Authenticator

  def self.title
    "magento"
  end

  def after_authenticate(params)
    position = params["position"].to_i
    installed_app = @current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:magento]).first
    installed_app.configs[:inputs]["shops"][position]["oauth_token"] = @omniauth.credentials.token
    installed_app.configs[:inputs]["shops"][position]["oauth_token_secret"] = @omniauth.credentials.secret
    installed_app.save!
    @result.flash_message = I18n.t(:'flash.application.setting_saved')
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider :magento, :setup => lambda { |env|
      query = Rack::Utils.parse_query(env['QUERY_STRING'])
      shop_no = query["position"].to_i
      account_id = query['origin'].split('=')[1]
      installed_app = nil
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        installed_app = account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:magento]).first
        env['omniauth.strategy'].options[:consumer_key] = installed_app.configs[:inputs]["shops"][shop_no]["consumer_token"]
        env['omniauth.strategy'].options[:consumer_secret] = installed_app.configs[:inputs]["shops"][shop_no]["consumer_secret"]
        env['omniauth.strategy'].options[:client_options]["site"] = installed_app.configs[:inputs]["shops"][shop_no]["shop_url"]
      end  
    }
  end

  def get_redirect_url
    "/integrations/applications"
  end
end
