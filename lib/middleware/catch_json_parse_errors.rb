class Middleware::CatchJsonParseErrors

  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue MultiJson::ParseError => error
      if env['HTTP_ACCEPT'] =~ /application\/json/ || env['HTTP_ACCEPT'] =~ /\*\/\*/ || env['CONTENT-TYPE'] = "application/json"
        error_output = "There was a problem in the JSON you submitted: #{error}"
        @status, @headers, @response = [400, { "Content-Type" => "application/json" }, [{:message => error_output }.to_json] ]
      else
        raise error
      end
    end
  end
end