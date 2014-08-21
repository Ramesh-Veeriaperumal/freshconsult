# TODO-RAILS3 Moved to application.rb
#config/initializers/omniauth.rb
# require 'openid/store/filesystem'
# require 'omniauth'
# require 'omniauth/strategies/twitter'
# require 'omniauth/strategies/nimble'

# ActionController::Dispatcher.middleware.use OmniAuth::Builder do


#   oauth_keys = Integrations::OauthHelper::get_oauth_keys
#   oauth_keys.map { |oauth_provider, key_hash|
#   if oauth_provider == "shopify"
#     provider :shopify, key_hash["consumer_token"], key_hash["consumer_secret"],
#              :scope => 'read_orders',
#              :setup => lambda { |env| params = Rack::Utils.parse_query(env['QUERY_STRING'])
#              env['omniauth.strategy'].options[:client_options][:site] = "https://#{params['shop']}" }
#   elsif key_hash["options"].blank?
# 	  provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"]
#   elsif key_hash["options"]["name"].blank?
#     provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], key_hash["options"]
#   else
#     provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], { scope: key_hash["options"]["scope"], name: key_hash["options"]["name"] }
#     key_hash["options"].delete "name"
#     provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], key_hash["options"]
#   end
#   }

#   # OmniAuth.origin on failure callback; so get it via params
#   # https://github.com/intridea/omniauth/issues/569
#   on_failure do |env|
#     message_key = env['omniauth.error.type']
#     origin = env['omniauth.origin']
#     new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{message_key}"
#     unless origin.blank?
#       origin = origin.split('?').last
#       new_path += "&origin=#{URI.escape(origin)}"
#     end
#     [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
#   end

#   provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')
# end


# # you will be able to access the above providers by the following url
# # /auth/providername for example /auth/twitter /auth/facebook

# ActionController::Dispatcher.middleware do
#   use OmniAuth::Strategies::OpenID,   OpenID::Store::Filesystem.new('./omnitmp') , :name => "google",  :identifier => "https://www.google.com/accounts/o8/id"
#   #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "yahoo",   :identifier => "https://me.yahoo.com"
#   #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "aol",     :identifier => "https://openid.aol.com"
#   #use OmniAuth::Strategies::OpenID, OpenID::Store::Filesystem.new('/tmp'), :name => "myspace", :identifier => "http://myspace.com"
# end
# # you won't be able to access the openid urls like /auth/google
# # you will be able to access them through
# # /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
# # /auth/open_id?openid_url=https://me.yahoo.com
