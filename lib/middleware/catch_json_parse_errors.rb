class Middleware::CatchJsonParseErrors

  #https://robots.thoughtbot.com/catching-json-parse-errors-with-custom-middleware
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
       @status, @headers, @response = @app.call(env)
      return [@status, @headers, @response]
    rescue MultiJson::ParseError => error
      @accept_header = env['HTTP_ACCEPT'] || env['HTTP-ACCEPT']
      @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']
      if json_request?
        error_output = "There was a problem in the JSON you submitted: #{error}"
        @status, @headers, @response = [400, { "Content-Type" => "application/json" }, [{:code => "invalid_json", :message => error_output}.to_json]]
      else
        raise error
      end
    end
    [@status, @headers, @response]
  end

  def json_request? 
    @accept_header =~ /application\/json/ || @accept_header =~ /\*\/\*/ || @content_type =~ /application\/json/ 
  end
end