class Middleware::ApiResponseWrapper
  WRAPPABLE_RESPONSE_CODES = [200, 202].freeze
  def initialize(app)
    @app = app
  end

  def call(env)
    @status, @headers, @response = @app.call(env)

    if to_be_wrapped?
      json_array = ["\"#{api_root_key}\": #{@response.body}"]
      json_array << ["\"meta\": #{JSON.generate(@response.api_meta)}"] if @response.respond_to?(:api_meta) && @response.api_meta
      @response.body = "{#{json_array.join(',')}}"
    end
    [@status, @headers, @response]
  end

  private

  def to_be_wrapped?
    defined?($infra) && 
      $infra['PRIVATE_API'] && 
      WRAPPABLE_RESPONSE_CODES.include?(@response.code.to_i) &&
      @response.respond_to?(:request) && 
      @response.request.env["ORIGINAL_FULLPATH"] && 
      @response.request.env["ORIGINAL_FULLPATH"].starts_with?('/api/_/') &&
      @headers["Content-Type"].present? &&
      @headers["Content-Type"].starts_with?(Mime::JSON)
  end
  
  def api_root_key
    @response.try(:api_root_key) || :data
  end
end