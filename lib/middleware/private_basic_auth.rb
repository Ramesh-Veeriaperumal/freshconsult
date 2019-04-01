class Middleware::PrivateBasicAuth
  include ErrorConstants

  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }.freeze
  BASIC_AUTH_PATTERN = /Basic (.*)/
  ERROR_MESSAGE = { code: :access_denied, message: ErrorConstants::ERROR_MESSAGES[:access_denied] }.to_json.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    @host = env['HTTP_HOST']
    @auth_header = env['HTTP_AUTHORIZATION']
    if CustomRequestStore.read(:private_api_request) && @auth_header && basic_auth?
      Rails.logger.debug "Private API Basic auth error :: Host: #{@host}"
      set_response(403, RESPONSE_HEADERS, ERROR_MESSAGE)
    else
      @status, @headers, @response = @app.call(env)
    end
    [@status, @headers, @response]
  end

  def basic_auth?
    BASIC_AUTH_PATTERN =~ @auth_header
  end

  def set_response(status, headers, message)
    @status   = status
    @headers  = headers
    @response = [message]
  end
end
