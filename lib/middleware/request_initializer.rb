class Middleware::RequestInitializer
  include Middleware::RequestVerifier

  def initialize(app)
    @app = app
  end

  def call(env)
    set_request_type(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end

  def set_request_type(env)
    CustomRequestStore.store[:api_request] = true if api_request?(env)
    CustomRequestStore.store[:pipe_api_request] = true if pipe_api_request?(env)
    CustomRequestStore.store[:private_api_request] = true if private_api_request?(env)
    CustomRequestStore.store[:freshid_api_request] = true if freshid_api_request?(env)
    CustomRequestStore.store[:channel_api_request] = true if channel_api_request?(env)
    CustomRequestStore.store[:api_v2_request] ||= true if api_v2_request?(env)
    CustomRequestStore.store[:apigee_api_request] = true if apigee_api_request?(env)
    CustomRequestStore.store[:widget_api_request] = true if widget_api_request?(env)
  end
end
