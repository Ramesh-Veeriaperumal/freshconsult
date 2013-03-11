#config/initializers/omniauth.rb
require 'openid/store/filesystem'
require 'omniauth'
require 'omniauth/strategies/twitter'
require 'omniauth/strategies/nimble'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do
  oauth_keys = Integrations::OauthHelper::get_oauth_keys
  oauth_keys.map { |oauth_provider, key_hash|
  if key_hash["options"].blank?
	  provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"]
	else
	  Rails.logger.debug "key_hash #{key_hash.inspect}"
	  provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], key_hash["options"]
	end
  }

  # OmniAuth.origin on failure callback; so get it via params
  # https://github.com/intridea/omniauth/issues/569
  on_failure do |env|
    message_key = env['omniauth.error.type']
    puts "omniauth.origin: #{env['omniauth.origin']}\n"
    origin = env['omniauth.origin'].split('?').last
    new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{message_key}&origin=#{URI.escape(origin)}"
    puts "Newpath: #{new_path}"
    [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
  end
  
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
