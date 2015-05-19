class Middleware::ApiRequestInterceptor

  CONTENT_TYPE_REQUIRED_METHODS = ['POST', 'PUT']

  #https://robots.thoughtbot.com/catching-json-parse-errors-with-custom-middleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @stop_proceeding = false
    @resource = env["PATH_INFO"]
    @method = env['REQUEST_METHOD'] || env['REQUEST-METHOD']
    @content_length = env['CONTENT_LENGTH'] || env['CONTENT-LENGTH']
    @content_type = env['CONTENT_TYPE'] || env['CONTENT-TYPE']
    @accept_header = env['HTTP_ACCEPT'] || env['HTTP-ACCEPT']
    validate_content_type if content_type_required? && api_request?
    validate_accept_header if @accept_header && api_request?
    begin
      @status, @headers, @response = @app.call(env) unless @stop_proceeding
    rescue MultiJson::ParseError, REXML::ParseException => error
      if api_request?
        error_output = "There was a problem in the JSON you submitted: #{error}"
        @status, @headers, @response = [400, { "Content-Type" => "application/json" }, [{:code => "invalid_json", :message => error_output}.to_json]]
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
    unless  @content_type =~ /application\/json/
      @stop_proceeding = true
      @status, @headers, @response = [415, {'Content-Type' => 'application/json'}, 
                                      [{:message => 'Content-Type header should have application/json', :code => 'invalid_content_type'}.to_json]]
    end
  end

  def validate_accept_header
    unless @accept_header =~ /(application\/json)|(\*\/\*)/
      @stop_proceeding = true
      @status, @headers, @response = [406, {'Content-Type' => 'application/json'}, 
                                      [{:message => 'Accept header should have application/json or */*', :code => 'invalid_accept_header'}.to_json]]
    end
  end

  def content_type_required?
    CONTENT_TYPE_REQUIRED_METHODS.include?(@method) && @content_length.to_i > 0
  end

end