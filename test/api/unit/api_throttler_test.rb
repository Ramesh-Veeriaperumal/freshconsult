require_relative '../unit_test_helper'

class ApiThrottlerTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_api_throttler_for_json_response_with_api_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::FdApiThrottler.new(test_app)
    api_throttler.stubs(:allowed?).returns(false)
    api_throttler.instance_variable_set('@api_limit', 1000)
    status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
         
                                                           'HTTP_HOST' => 'localhost.freshpo.com')
    assert_equal 429, status
    assert_equal true, ['Retry-After', 'Content-Type'].all? { |key| headers.key? key }
    assert_equal ["{\"message\":\"You have exceeded the limit of requests per hour\"}"], response
  end

  def test_api_throttler_for_json_response_without_api_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    api_throttler.stubs(:allowed?).returns(false)
    status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/discussions/categories',
                                                           'HTTP_HOST' => 'localhost.freshpo.com')
    assert_equal 403, status
    assert_equal true, ['Retry-After', 'Content-Type'].all? { |key| headers.key? key }
    assert headers['Content-Type'] == 'text/html'
    assert_not_nil response
  end

  def test_api_throttler_for_json_response_with_content_type
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    api_throttler.stubs(:allowed?).returns(true)
    status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/discussions/categories',
                                                           'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT_TYPE' => 'application/json')
    assert_equal 200, status
    assert_not_nil response
  end
end
