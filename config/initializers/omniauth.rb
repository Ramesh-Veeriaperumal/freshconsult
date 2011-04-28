#config/initializers/omniauth.rb
require 'openid/store/filesystem'


Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid, nil, :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
end