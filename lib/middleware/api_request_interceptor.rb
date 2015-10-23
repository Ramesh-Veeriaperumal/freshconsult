class Middleware::ApiRequestInterceptor
  CONTENT_TYPE_REQUIRED_METHODS = ['POST', 'PUT']
  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }

  # https://robots.thoughtbot.com/catching-json-parse-errors-with-custom-middleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @resource = env['PATH_INFO']
    unless api_request?
      @status, @headers, @response = @app.call(env)
    else
      valid_content_type = valid_accept_header = true
      extract_request_attributes(env)
      if content_type_required_method?
        valid_content_type = validate_content_type 
      elsif ['GET', 'DELETE'].include?(@method)
        env["CONTENT_TYPE"] = env["Content-Type"] = nil
      end
      valid_accept_header = validate_accept_header if @accept_header 
      begin
        @status, @headers, @response = @app.call(env) if valid_content_type && valid_accept_header
      rescue MultiJson::ParseError => error
        Rails.logger.error("API MultiJson::ParseError: #{error.data.string} \n#{error.message}\n#{error.backtrace.join("\n")}")
        message =  { code: 'invalid_json', message: "Request body has invalid json format" }
        set_response(400, RESPONSE_HEADERS, message)
      rescue StandardError => error
        notify_new_relic_agent(error, env['REQUEST_URI'], { description: "Error occurred while processing API", request_method: env['REQUEST_METHOD'], request_body: env["rack.input"].string})
        Rails.logger.error("API StandardError: #{error.message}\n#{error.backtrace.join("\n")}")
        message =  { code: 'internal_error', message: "We're sorry, but something went wrong." }
        set_response(500, RESPONSE_HEADERS, message)
      end
    end
    [@status, @headers, @response]
  end

  def api_request?
    @resource.starts_with?('/api/')
  end

  def validate_content_type
    unless  @content_type =~ /multipart\/form-data|application\/json/
      Rails.logger.error("API Un_supported content_type:#{@content_type} is sent in the request")
      set_response(415, RESPONSE_HEADERS, message: 'Content-Type header should have application/json', code: 'invalid_content_type')
      return false
    end
    true
  end

  def validate_accept_header
    unless @accept_header =~ /(application\/json)|(\*\/\*)|(application\/vnd.freshdesk.v\d)/
      Rails.logger.error("API Not_acceptable accept_header:#{@accept_header} is sent in the request")
      set_response(406, RESPONSE_HEADERS, message: 'Accept header should have application/json or */*', code: 'invalid_accept_header')
      return false
    end
    true
  end

  def extract_request_attributes(env)
    @method = env['REQUEST_METHOD'] || env['REQUEST-METHOD']
    @content_length = env['CONTENT_LENGTH'] || env['CONTENT-LENGTH']
    @content_type = env['CONTENT_TYPE'] || env['CONTENT-TYPE']
    @accept_header = env['HTTP_ACCEPT'] || env['HTTP-ACCEPT']
  end

  def set_response(status, headers, message)
    @status, @headers, @response = [status, headers, [message.to_json]]
  end

  def content_type_required_method?
    CONTENT_TYPE_REQUIRED_METHODS.include?(@method)
  end

  def notify_new_relic_agent(exception, uri, custom_params={})
    options_hash =  custom_params.present? ? { custom_params: custom_params } : {}
    NewRelic::Agent.notice_error(exception, {uri: uri}.merge(options_hash))
  end
end
