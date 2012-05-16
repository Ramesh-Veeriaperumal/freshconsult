#config/initializers/omniauth.rb
require 'openid/store/filesystem'
require 'omniauth'
require 'omniauth/strategies/salesforce'
require 'omniauth/strategies/twitter'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do
  oauth_s = Integrations::GoogleContactsUtil.get_oauth_keys
   provider :google, oauth_s[0], oauth_s[1]
   if Rails.env.production?
    provider :twitter,  'dJ8tRu32g8UfWpPgs3bg', 'Brp3pT6z9JTGvCB1dWLEIHLBEre8Yy9lEFGZXwfUo'
   elsif Rails.env.staging?
    provider :twitter,  'dr1GMNCkYqUqjPTvWoY4nQ', 'QUbXWcl5dOAdylf3eSCjD0XnFRpUOErUVId3RKMc'
   elsif Rails.env.development?
    provider :twitter,  'dr1GMNCkYqUqjPTvWoY4nQ', 'QUbXWcl5dOAdylf3eSCjD0XnFRpUOErUVId3RKMc'
   end
  # provider :facebook, 'APP_ID', 'APP_SECRET'
  # provider :linked_in, 'KEY', 'SECRET'
   provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')
   provider :salesforce, '3MVG9rFJvQRVOvk736MwC8D50iroLs6.IXQz_2Dsw4horjvxgK3tQcd7q7Pa2bcoemvR4_afG4u7PeUU8ZuFn', '3480279088976514323'
   provider :facebook, '349175231814370', 'a1f93b85452d688e2248cab489a5429f'
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
