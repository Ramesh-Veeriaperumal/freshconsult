class Middleware::ApiResponseWrapper
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    @status, @headers, @response = @app.call(env)
    if to_be_wrapped?
      json_array = ["\"data\": #{@response.body}"]
      json_array << ["\"meta\": #{JSON.generate(@response.api_meta)}"] if @response.respond_to?(:api_meta) && @response.api_meta
      @response.body = "{#{json_array.join(',')}}"
    end
    [@status, @headers, @response]
  end
  
  private
  
  def to_be_wrapped?
    defined?($infra) && 
      $infra['PRIVATE_API'] && 
      @response.respond_to?(:request) && 
      @response.request.env["ORIGINAL_FULLPATH"] && 
      @response.request.env["ORIGINAL_FULLPATH"].starts_with?('/api/_/') &&
      @headers["Content-Type"].present? &&
      @headers["Content-Type"].starts_with?(Mime::JSON)
  end
end