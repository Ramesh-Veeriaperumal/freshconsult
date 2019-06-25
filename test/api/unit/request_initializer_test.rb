require_relative '../unit_test_helper'

class RequestInitializerTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_request_initializer_with_channel_api_path_with_double_slash
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = 'channel'
    custom_store = 'channel_v1'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com//api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_request_initializer_with_channel_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = 'channel'
    custom_store = 'channel_v1'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_api_throttler_for_json_response_with_private_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = '_'
    custom_store = 'private'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_api_throttler_for_json_response_with_pipe_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = custom_store = 'pipe'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_api_throttler_for_json_response_with_freshid_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = custom_store = 'freshid'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_api_throttler_for_json_response_with_channel_v2_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = 'channel/v2'
    custom_store = 'channel'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  def test_api_throttler_for_json_response_with_widget_api_path
    clear_custom_store
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    request_initializer = Middleware::RequestInitializer.new(test_app)
    resource = custom_store = 'widget'
    request_initializer.set_request_type env_for("http://localhost.freshpo.com/api/#{resource}/tickets", 'HTTP_HOST' => 'localhost.freshpo.com')
    check_result(custom_store)
  end

  private

    def clear_custom_store
      CustomRequestStore.clear!
    end

    def check_result(custom_store)
      Middleware::RequestInitializer::REQUEST_TYPES.each do |type|
        next if type.eql? custom_store

        assert_equal CustomRequestStore.store[type.to_sym], nil
      end
      assert_equal CustomRequestStore.store["#{custom_store}_api_request".to_sym], true
    end
end
