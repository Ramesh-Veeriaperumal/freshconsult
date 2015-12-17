require 'omniauth/strategies/oauth'
require 'multi_json'

module OmniAuth
  module Strategies
    class Magento < OmniAuth::Strategies::OAuth
      option :name, "magento"

      option :client_options, {
        :request_token_path => "/oauth/initiate",          
        :authorize_path     => "/admin/oauth_authorize",          
        :access_token_path  => "/oauth/token"
      }            
    end
  end
end