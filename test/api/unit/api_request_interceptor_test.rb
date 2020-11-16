require_relative '../unit_test_helper'
require_relative '../helpers/json_pattern'

class ApiRequestInterceptorTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_catch_json_parse_errors_for_json_content_type
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError.build(MultiJson::ParseError.new, StringIO.new("{\"dfdfdd\"}")), 'message')
    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    assert_equal true, ['Content-Type'].all? { |key| headers.key? key }
    response.first.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_catch_invalid_xml_content_type_non_api_v2
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(Nokogiri::XML::SyntaxError.new(StringIO.new('{"dfdfdd"}')))

    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/random/radom.xml',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/xml'))
    assert_equal 400, status
    assert_equal true, (['Content-Type'].all? { |key| headers.key? key })
  end

  def test_catch_invalid_json_content_type_non_api_v2
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError.build(MultiJson::ParseError.new, StringIO.new('{"dfdfdd"}')), 'message')

    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/random/radom.json',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    assert_equal true, (['Content-Type'].all? { |key| headers.key? key })
  end

  def test_catch_json_parse_errors_for_others
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, 'message')
    assert_nothing_raised(MultiJson::ParseError) do
      api_request_interceptor.call(env_for('http://localhost.freshpo.com/discussions/categories.json',
                                           'HTTP_HOST' => 'localhost.freshpo.com'))
    end
  end

  def test_catch_invalid_json_content_type_non_api_v2_valid_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError.build(MultiJson::ParseError.new, StringIO.new('{"dfdfdd"}')), 'message')

    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/discussions/categories.json',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    assert_equal true, (['Content-Type'].all? { |key| headers.key? key })
  end

  def test_catch_json_parse_errors_for_older_version
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, 'message')
    assert_nothing_raised(MultiJson::ParseError) do
      api_request_interceptor.call(env_for('http://localhost.freshpo.com/discussions/categories',
                                           'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    end
  end

  def test_catch_json_parse_errors_valid
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).returns([200, { 'HTTP_HOST' => 'localhost' }, ['OK']])
    assert_nothing_raised do
      api_request_interceptor.call(env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                           'HTTP_HOST' => 'localhost.freshpo.com'))
    end
  end

  def test_invalid_encoding_error
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(ArgumentError.new('invalid %-encoding (%dfdgdgg)'))
    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/api/v2/discussions/categories?email=invalid_error',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    response.first.must_match_json_expression(message: String, code: 'invalid_encoding')
  end
end
