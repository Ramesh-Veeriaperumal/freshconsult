class Middleware::ApiRequestInterceptor
  CONTENT_TYPE_REQUIRED_METHODS = ['POST', 'PUT']
  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }

  # https://robots.thoughtbot.com/catching-json-parse-errors-with-custom-middleware
  def initialize(app)
    @app = app
  end

  def call(env)
    valid_content_type = valid_accept_header = true
    extract_request_attributes(env)
    valid_content_type = validate_content_type if content_type_required? && api_request?
    valid_accept_header = validate_accept_header if @accept_header && api_request?
    begin
      @status, @headers, @response = @app.call(env) if valid_content_type && valid_accept_header
    rescue MultiJson::ParseError => error
      if api_request?
        Rails.logger.error("API MultiJson::ParseError: #{error.data.string} \n#{error.message}\n#{error.backtrace.join("\n")}")
        message =  { code: 'invalid_json', message: "There was a problem in the JSON you submitted: #{error.data.string}" }
        set_response(400, RESPONSE_HEADERS, message)
      else
        raise error
      end
    end
    [@status, @headers, @response]
  end

  def api_request?
    @resource.starts_with?('/api/')
  end

  def validate_content_type
    unless  @content_type =~ /multipart\/form-data|application\/json/
      set_response(415, RESPONSE_HEADERS, message: 'Content-Type header should have application/json', code: 'invalid_content_type')
      return false
    end
    true
  end

  def validate_accept_header
    unless @accept_header =~ /(application\/json)|(\*\/\*)/
      set_response(406, RESPONSE_HEADERS, message: 'Accept header should have application/json or */*', code: 'invalid_accept_header')
      return false
    end
    true
  end

  def extract_request_attributes(env)
    @resource = env['PATH_INFO']
    @method = env['REQUEST_METHOD'] || env['REQUEST-METHOD']
    @content_length = env['CONTENT_LENGTH'] || env['CONTENT-LENGTH']
    @content_type = env['CONTENT_TYPE'] || env['CONTENT-TYPE']
    @accept_header = env['HTTP_ACCEPT'] || env['HTTP-ACCEPT']
  end

  def set_response(status, headers, message)
    @status, @headers, @response = [status, headers, [message.to_json]]
  end

  def content_type_required?
    CONTENT_TYPE_REQUIRED_METHODS.include?(@method) && @content_length.to_i > 0
  end
end
