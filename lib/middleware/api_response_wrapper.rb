class Middleware::ApiResponseWrapper
  WRAPPABLE_RESPONSE_CODES = [200, 201, 202].freeze
  def initialize(app)
    @app = app
  end

  def call(env)
    @status, @headers, @response = @app.call(env)

    if to_be_wrapped?
      json_array = ["\"#{api_root_key}\": #{@response.body}"]
      json_array << ["\"meta\": #{@response.api_meta.to_json}"] if @response.respond_to?(:api_meta) && @response.api_meta
      @response.body = "{#{json_array.join(',')}}"
    end
    [@status, @headers, @response]
  end

  private

  def to_be_wrapped?
    CustomRequestStore.read(:private_api_request) &&

    @response.respond_to?(:request) &&
    @response.request.env["ORIGINAL_FULLPATH"] &&
    @response.request.env["ORIGINAL_FULLPATH"].starts_with?('/api/_/') &&
    !@response.request.env["ORIGINAL_FULLPATH"].include?('/ocr_proxy/') &&
    !@response.request.env['ORIGINAL_FULLPATH'].include?('/autofaq/') &&
    !@response.request.env['ORIGINAL_FULLPATH'].include?('/botflow/') &&
      !(@response.request.env['ORIGINAL_FULLPATH'].include?('/dashboards/') && !@response.request.env['ORIGINAL_FULLPATH'].include?('/widgets_data') && @response.request.env['ORIGINAL_FULLPATH'].include?('/widgets')) &&

    @response.respond_to?(:code) &&
    WRAPPABLE_RESPONSE_CODES.include?(@response.code.to_i) &&

    @headers["Content-Type"].present? &&
    @headers["Content-Type"].starts_with?(Mime::JSON)
  end

  def api_root_key
    @response.try(:api_root_key) || :data
  end
end