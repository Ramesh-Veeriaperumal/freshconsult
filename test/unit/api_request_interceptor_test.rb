require_relative '../test_helper'

class ApiRequestInterceptorTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_catch_json_parse_errors_for_json_content_type
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, 'message')
    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    assert_equal true, ['Content-Type'].all? { |key| headers.key? key }
    response.first.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_catch_json_parse_errors_for_others
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, 'message')
    assert_raises(MultiJson::ParseError) do
      api_request_interceptor.call(env_for('http://localhost.freshpo.com/discussions/categories.json',
                                           'HTTP_HOST' => 'localhost.freshpo.com'))
    end
  end

  def test_catch_json_parse_errors_for_older_version
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, 'message')
    assert_raises(MultiJson::ParseError) do
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

  def test_rexml_parse_exception_for_xml_content
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_request_interceptor = Middleware::ApiRequestInterceptor.new(test_app)
    api_request_interceptor.instance_variable_get(:@app).stubs(:call).raises(REXML::ParseException, 'message')
    status, headers, response = api_request_interceptor.call(env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                                     'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT-TYPE' => 'application/json'))
    assert_equal 400, status
    assert_equal true, ['Content-Type'].all? { |key| headers.key? key }
    response.first.must_match_json_expression(invalid_json_error_pattern)
  end
end
