# this class is used by the user and OmniauthCallbacks controllers, it controls how
#  an authentication system interacts with our database and middleware

class Auth::Authenticator
  include Integrations::OauthHelper

  def self.inherited(klass)
    @auth_classes ||= {}
    @auth_classes[klass.name.split('::').last.underscore.split('_')[0...-1].join('_')] = klass
  end

  def self.authenticators
    @auth_classes
  end

  def self.get_auth_class(auth_name)
    @auth_classes[auth_name]
  end

  def initialize(options = {})
    @app = options[:app]
    @origin_account = options[:origin_account]
    @portal_url = options[:portal_url]
    @result = Auth::Result.new
    @current_account = options[:current_account]
    @omniauth = options[:omniauth]
    @user_id = options[:user_id]
  end

  def name
    self.class.title
  end

  def after_authenticate(auth_options, params)
    raise NotImplementedError
  end

  # hook used for registering omniauth middleware,
  #  without this we can not authenticate
  def register_middleware(omniauth)
    raise NotImplementedError
  end

  def get_redirect_url
    raise NotImplementedError
  end

  def set_redis_keys(config_params, expire_time = nil)
    key_options = { :account_id => @origin_account.id, :provider => @app.name}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => expire_time || 300}).set_key
  end
end
Dir["#{Rails.root}/lib/auth/*.rb"].each { |f| require_dependency(f) }
