class Middleware::RequestInitializer
  include Middleware::RequestVerifier
  REQUEST_TYPES = ['pipe', 'private', 'freshid', 'channel', 'channel_v1', 'widget', 'cron'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    set_request_type(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end

  def set_request_type(env)
    resource = trim_multiple_slashes(env['PATH_INFO'])
    return unless api_request?(resource)

    CustomRequestStore.store[:api_request] = true
    REQUEST_TYPES.each do |type|
      return CustomRequestStore.store["#{type}_api_request".to_sym] = true if safe_send("#{type}_api_request?", resource)
    end
    CustomRequestStore.store[:api_v2_request] = true
  end

  private

    def trim_multiple_slashes(resource)
      resource.gsub(/^\/+/, '/')
    end
end
