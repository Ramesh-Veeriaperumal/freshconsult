require_relative '../unit_test_helper'

class PrivateApiThrottlerTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_private_api_throttler_for_json_response_with_api_path
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::PrivateApiThrottler.new(test_app)
    set_unset_custom_request_store(:private_api_request) do
      api_throttler.stubs(:allowed?).returns(false)
      api_throttler.stubs(:throttle?).returns(true)
      api_throttler.instance_variable_set('@api_limit', 0)
      api_throttler.stubs(:api_limit).returns(0)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/_/bootstrap',

                                                             'HTTP_HOST' => 'localhost.freshpo.com')
      assert_equal 429, status
      assert_equal true, (['Retry-After', 'Content-Type'].all? { |key| headers.key? key })
      assert_equal ['{"message":"You have exceeded the limit of requests per hour"}'], response
    end
  end

  def test_privte_api_throttler_for_valid_request
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::PrivateApiThrottler.new(test_app)
    set_unset_custom_request_store(:private_api_request) do
      api_throttler.stubs(:allowed?).returns(true)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/_/bootstrap',
                                                             'HTTP_HOST' => 'localhost.freshpo.com')
      assert_equal 200, status
      assert_not_nil response
    end
  end

  def test_privte_api_throttler_to_check_throttle_limit
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_throttler = Middleware::PrivateApiThrottler.new(test_app)
    set_unset_custom_request_store(:private_api_request) do
      api_throttler.instance_variable_set('@api_limit', 1000)
      api_throttler.stubs(:allowed?).returns(true)
      api_throttler.stubs(:throttle?).returns(false)
      status, headers, response = api_throttler.call env_for('http://localhost.freshpo.com/api/_/bootstrap',
                                                             'HTTP_HOST' => 'localhost.freshpo.com')
      assert_equal 200, status
      assert_not_nil response
    end
  end

  private

    def set_unset_custom_request_store(key)
      CustomRequestStore.store[key] = true
      yield
      CustomRequestStore.clear!
    end
end
