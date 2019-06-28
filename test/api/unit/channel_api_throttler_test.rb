require_relative '../unit_test_helper'

class ChannelApiThrottlerTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_channel_api_throttler_for_json_response_with_api_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ChannelApiThrottler.new(test_app)
    set_unset_custom_request_store(:channel_api_request) do
      api_throttler.stubs(:api_limit).returns(0)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/channel/v2/tickets', 'HTTP_HOST' => 'localhost.freshpo.com')
      assert_equal 429, status
      assert_equal true, ['Retry-After', 'Content-Type'].all? { |key| headers.key? key }
      assert_equal ['{"message":"You have exceeded the limit of requests per hour"}'], response
      api_throttler.unstub(:api_limit)
    end
  end

  def test_channel_api_throttler_for_json_response_with_content_type
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ChannelApiThrottler.new(test_app)
    set_unset_custom_request_store(:channel_api_request) do
      api_throttler.stubs(:allowed?).returns(true)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/channel/v2/tickets', 'REQUEST_URI' => 'http://localhost.freshpo.com/discussions/categories', 'HTTP_USER_AGENT' => 'curl/7.43.0', 'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT_TYPE' => 'application/json')
      assert_equal 200, status
      assert_not_nil response
      api_throttler.unstub(:allowed?)
    end
  end

  def test_channel_v1_api_throttler_for_json_response_with_api_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ChannelApiThrottler.new(test_app)
    set_unset_custom_request_store(:channel_v1_api_request) do
      api_throttler.stubs(:api_limit).returns(0)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/channel/tickets', 'HTTP_HOST' => 'localhost.freshpo.com')
      assert_equal 429, status
      assert_equal true, ['Retry-After', 'Content-Type'].all? { |key| headers.key? key }
      assert_equal ['{"message":"You have exceeded the limit of requests per hour"}'], response
      api_throttler.unstub(:api_limit)
    end
  end

  def test_channel_v1_api_throttler_for_json_response_with_content_type
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::ChannelApiThrottler.new(test_app)
    set_unset_custom_request_store(:channel_v1_api_request) do
      api_throttler.stubs(:allowed?).returns(true)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/channel/tickets', 'REQUEST_URI' => 'http://localhost.freshpo.com/discussions/categories', 'HTTP_USER_AGENT' => 'curl/7.43.0', 'HTTP_HOST' => 'localhost.freshpo.com', 'CONTENT_TYPE' => 'application/json')
      assert_equal 200, status
      assert_not_nil response
      api_throttler.unstub(:allowed?)
    end
  end

  private

    def set_unset_custom_request_store(key)
      CustomRequestStore.store[key] = true
      yield
      CustomRequestStore.clear!
    end
end
