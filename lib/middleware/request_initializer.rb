class Middleware::RequestInitializer
  include Middleware::RequestVerifier
  REQUEST_TYPES = ['pipe', 'private', 'freshid', 'channel', 'channel_v1', 'widget'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    set_request_type(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end

  def set_request_type(env)
    return unless api_request?(env)

    CustomRequestStore.store[:api_request] = true
    REQUEST_TYPES.each do |type|
      if safe_send("#{type}_api_request?", env)
        return CustomRequestStore.store["#{type}_api_request".to_sym] = true
      end
    end
    CustomRequestStore.store[:api_v2_request] = true
  end
end
