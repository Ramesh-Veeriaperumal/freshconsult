class Middleware::ApiCronAuthenticator
  include ErrorConstants
  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }.freeze
  AUTH_HEADER = 'HTTP_X_FRESHDESK_CRON_WEBHOOK_KEY'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    @resource = env['PATH_INFO']
    @host = env['HTTP_HOST']
    if !CustomRequestStore.read(:cron_api_request)
      @status, @headers, @response = @app.call(env)
    else
      secret = env.delete(AUTH_HEADER)
      if (CRON_HOOK_DOMAIN.eql? @host) && (CRON_HOOK_AUTH_KEY.eql? secret)
        @status, @headers, @response = @app.call(env)
      elsif CRON_HOOK_ACCOUNT_AUTH_KEY.eql? secret
        @status, @headers, @response = @app.call(env)
      else
        set_response(403, RESPONSE_HEADERS)
      end
    end
    [@status, @headers, @response]
  end

  def set_response(status, headers)
    @status = status
    @headers = headers
    @response = nil
  end
end
