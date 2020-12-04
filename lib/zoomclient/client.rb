module Zoomclient
  class Client

    include HTTParty
    include Zoomclient::Actions::User
    include Zoomclient::Actions::Meeting
    include Zoomclient::Utils

    base_uri 'https://api.zoom.us/v2'

    def initialize(*args)

      options = extract_options!(args)

      raise argument_error("auth_token") unless options[:auth_token]
      self.class.default_params(auth_token: options[:auth_token])
      self.class.headers 'Authorization' => "Bearer #{options[:auth_token]}"
      self.class.headers 'Content-type' => 'application/json'
      self.class.default_timeout(15)
    end
  end
end
