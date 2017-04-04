class Middleware::ApiPipeAuthenticator
  include ErrorConstants
  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }.freeze
  
  def initialize(app)
    @app = app
  end

  def call(env)
    @resource = env['PATH_INFO']
    @host = env['HTTP_HOST']
    unless pipe_request?
      @status, @headers, @response = @app.call(env)
    else
      secret = env.delete('HTTP_PIPESECRET')
      if Freshpipe::SECRET_KEYS.include?(secret)
        @status, @headers, @response = @app.call(env)
      else
        message =  { code: :access_denied, message: ErrorConstants::ERROR_MESSAGES[:access_denied]}

        set_response(404, RESPONSE_HEADERS)
      end
    end
    [@status, @headers, @response]
  end

  def pipe_request?
    @resource.starts_with?('/api/pipe/')
  end

  def set_response(status, headers)
    @status, @headers, @response = [status, headers, nil]
  end
end
