#config/initializers/omniauth.rb
require 'openid/store/filesystem'
require 'omniauth'
require 'omniauth/strategies/salesforce'
require 'omniauth/strategies/twitter'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do
  oauth_keys = Integrations::OauthHelper.get_oauth_keys
  provider :google, oauth_keys[:google][:consumer_key], oauth_keys[:google][:consumer_secret]
  provider :twitter,  oauth_keys[:twitter][:consumer_key], oauth_keys[:twitter][:consumer_secret]
  provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')
  provider :salesforce, oauth_keys[:salesforce][:consumer_key], oauth_keys[:salesforce][:consumer_secret]
  #provider :salesforce, '3MVG9rFJvQRVOvk736MwC8D50imcmC8mwRYbuC9cSVuq98AuOSCEfPHpLPPvOHDgr3IsFQplzOz7f5c.JID7c', '1614738053314605388'
  provider :facebook, oauth_keys[:facebook][:consumer_key], oauth_keys[:facebook][:consumer_secret]
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
