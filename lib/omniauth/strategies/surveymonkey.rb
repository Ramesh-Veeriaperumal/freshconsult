module OmniAuth
  module Strategies
    class Surveymonkey < OmniAuth::Strategies::OAuth2

     configure url: 'https://www.surveymonkey.com/oauth/authorize'

     args [:client_id, :client_secret]

     option :client_options, {
        :site => "https://api.surveymonkey.net",
        :authorize_url => '/oauth/authorize',
        :token_url => '/oauth/token'
      }

     def callback_phase
        super
      end

    end
  end
end