#config/initializers/omniauth.rb
require 'openid/store/filesystem'
require 'omniauth'
require 'omniauth/strategies/twitter'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do
  oauth_keys = Integrations::OauthHelper.get_oauth_keys
  oauth_keys.map { |oauth_provider, key_hash|
    provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"]
  }
  provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')
end


# you will be able to access the above providers by the following url
# /auth/providername for example /auth/twitter /auth/facebook

ActionController::Dispatcher.middleware do
  use OmniAuth::Strategies::OpenID,   OpenID::Store::Filesystem.new('./omnitmp') , :name => "google",  :identifier => "https://www.google.com/accounts/o8/id"
  #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "yahoo",   :identifier => "https://me.yahoo.com"
  #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "aol",     :identifier => "https://openid.aol.com"
  #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "myspace", :identifier => "http://myspace.com"
end
# you won't be able to access the openid urls like /auth/google
# you will be able to access them through
# /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
# /auth/open_id?openid_url=https://me.yahoo.com
