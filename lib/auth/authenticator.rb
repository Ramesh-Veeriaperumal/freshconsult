# this class is used by the user and OmniauthCallbacks controllers, it controls how
#  an authentication system interacts with our database and middleware

class Auth::Authenticator
  include Integrations::OauthHelper

  def self.title
    raise NotImplementedError
  end

  def self.authenticators
    return @auth_classes if @auth_classes
    subclasses = {}
    ObjectSpace.each_object(Module) {|m| subclasses[m.title] =  m if m.ancestors.include?(Auth::Authenticator) && m.name != 'Auth::Authenticator' }
    @auth_classes = subclasses
  end

  def self.get_auth_class(auth_name)
    authenticators[auth_name]
  end

  def initialize(options = {})
    @app = options[:app]
    @origin_account = options[:origin_account]
    @portal_url = options[:portal_url]
    @result = Auth::Result.new
    @current_account = options[:current_account]
    @omniauth = options[:omniauth]
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
