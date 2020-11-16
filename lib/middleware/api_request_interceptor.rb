class Middleware::ApiRequestInterceptor
  include ErrorConstants

  CONTENT_TYPE_REQUIRED_METHODS = ['POST', 'PUT'].freeze
  RESPONSE_HEADERS = { 'Content-Type' => 'application/json' }.freeze
  XML_RESPONSE_HEADERS = { 'Content-Type' => 'application/xml' }.freeze
  INVALID_CONTENT_TYPE = 'invalid_content_type'.freeze
  INVALID_JSON = 'invalid_json'.freeze
  INVALID_XML = 'invalid_xml'.freeze
  INTERNAL_ERROR = 'internal_error'.freeze
  INVALID_ENCODING = 'invalid_encoding'.freeze
  INVALID_ACCEPT_HEADER = 'invalid_accept_header'.freeze

  # https://robots.thoughtbot.com/catching-json-parse-errors-with-custom-middleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @resource = env['PATH_INFO']
    @host = env['HTTP_HOST']
    begin
      if api_request?
        valid_content_type = valid_accept_header = true
        extract_request_attributes(env)
        if content_type_required_method?
          valid_content_type = validate_content_type
        elsif %w[GET DELETE].include?(@method)
          env['CONTENT_TYPE'] = env['Content-Type'] = nil
        end
        valid_accept_header = validate_accept_header if @accept_header
        @status, @headers, @response = @app.call(env) if valid_content_type && valid_accept_header
      else
        @status, @headers, @response = @app.call(env)
      end
    rescue ArgumentError => e
      # If url query string has invalid encoding like '%' symbol, argument error will be thrown from ruby side.
      # # Hence gracefully handling this issue.
      e.message.starts_with?('invalid %-encoding') ? invalid_encoding_error(e) : respond_500(e, env)
    rescue MultiJson::ParseError => e
      invalid_json_error(e, env)
    rescue Nokogiri::XML::SyntaxError => e
      invalid_xml_error(e)
    rescue StandardError => e
      respond_500(e, env)
    end
    [@status, @headers, @response]
  end

  def api_request?
    @resource.starts_with?('/api/')
  end

  def invalid_json_error(error, env)
    Rails.logger.error("API MultiJson::ParseError :: Host: #{@host}, #{env['rack.input'].read} \n#{error.message}\n#{error.backtrace.join("\n")}")
    message =  { code: INVALID_JSON, message: ErrorConstants::ERROR_MESSAGES[:invalid_json] }
    set_response(400, RESPONSE_HEADERS, message)
  end

  def invalid_xml_error(error)
    Rails.logger.error("API Nokogiri::XML::SyntaxError :: Host: #{@host},  #{error.message}, #{error.backtrace[0..10].inspect}")
    message = { code: INVALID_XML, message: ErrorConstants::ERROR_MESSAGES[:invalid_xml] }
    set_response(400, XML_RESPONSE_HEADERS, message)
  end

  def respond_500(error, env)
    notify_new_relic_agent(error, env['REQUEST_URI'], env['action_dispatch.request_id'], description: 'Error occurred while processing API', request_method: env['REQUEST_METHOD'])
    Rails.logger.error("API StandardError ::  Host: #{@host}, #{error.message}\n#{error.backtrace.join("\n")}")
    message =  { code: INTERNAL_ERROR, message: ErrorConstants::ERROR_MESSAGES[:internal_error] }
    set_response(500, RESPONSE_HEADERS, message)
  end

  def invalid_encoding_error(error)
    Rails.logger.error("API Invalid Encoding error :: Host: #{@host}, #{error.message}\n#{error.backtrace.join("\n")}")
    invalid_query_string = error.message.sub('invalid %-encoding (', '').chop
    message =  { code: INVALID_ENCODING, message: ErrorConstants::ERROR_MESSAGES[:invalid_encoding] % { invalid_query_string: invalid_query_string } }
    set_response(400, RESPONSE_HEADERS, message)
  end

  def validate_content_type
    unless @content_type =~ /multipart\/form-data|application\/json|application\/x-www-form-urlencoded/
      Rails.logger.error("API Un supported content_type error ::  Host: #{@host}, content_type:#{@content_type} is sent in the request")
      message = { code: INVALID_CONTENT_TYPE, message: ErrorConstants::ERROR_MESSAGES[:invalid_content_type] % {content_type: @content_type} }
      set_response(415, RESPONSE_HEADERS, message)
      return false
    end
    true
  end

  def validate_accept_header
    unless @accept_header =~ /(application\/json)|(\*\/\*)|(application\/vnd.freshdesk.v\d)/
      Rails.logger.error("API not acceptable header error ::  Host: #{@host}, accept_header:#{@accept_header} is sent in the request")
      message = { code: INVALID_ACCEPT_HEADER, message: ErrorConstants::ERROR_MESSAGES[:invalid_accept_header] % { accept_header: @accept_header } }
      set_response(406, RESPONSE_HEADERS, message)
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
    @content_length && CONTENT_TYPE_REQUIRED_METHODS.include?(@method)
  end

  def notify_new_relic_agent(exception, uri, request_id, custom_params = {})
    options_hash =  { uri: uri, custom_params: custom_params.merge(x_request_id: request_id) }
    NewRelic::Agent.notice_error(exception, options_hash)
  end
end
