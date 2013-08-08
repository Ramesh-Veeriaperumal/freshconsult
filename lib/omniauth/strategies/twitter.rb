require 'omniauth-oauth'
require 'multi_json'

module OmniAuth
  module Strategies
    class Twitter < OmniAuth::Strategies::OAuth
      option :name, 'twitter'
      option :client_options, {:authorize_path => '/oauth/authenticate',
                               :site => 'https://api.twitter.com'}

      uid { access_token.params[:user_id] }

      info do
        {
          :nickname => raw_info['screen_name'],
          :name => raw_info['name'],
          :location => raw_info['location'],
          :image => raw_info['profile_image_url'],
          :description => raw_info['description'],
          :urls => {
            'Website' => raw_info['url'],
            'Twitter' => "https://twitter.com/#{raw_info['screen_name']}",
          }
        }
      end

      extra do
        { :raw_info => raw_info }
      end

      def raw_info
        @raw_info ||= MultiJson.load(
          access_token.get('/1.1/account/verify_credentials.json?include_entities=false&skip_status=true').body)
      rescue ::Errno::ETIMEDOUT
        raise ::Timeout::Error
      end

      alias :old_request_phase :request_phase

      def request_phase 
        #screen_name = session['omniauth.params']['screen_name']  
        screen_name = ""
        x_auth_access_type = session['omniauth.params'] ? session['omniauth.params']['x_auth_access_type'] : nil
        if screen_name && !screen_name.empty?
          options[:authorize_params] ||= {}
          options[:authorize_params].merge!(:screen_name => screen_name)
        end
        if x_auth_access_type
          options[:request_params] || {}
          options[:request_params].merge!(:x_auth_access_type => x_auth_access_type)
        end
        old_request_phase
      end


    end
  end
end