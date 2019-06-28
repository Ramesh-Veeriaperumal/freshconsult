require_relative '../../test_helper'
class ApplicationLoggerTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_application_logger
    test_app   = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_logger = Middleware::ApplicationLogger.new(test_app)
    Middleware::ApplicationLogger.any_instance.stubs(:controller_log_info).returns(account_id: 1, user_id: 1, shard_name: 'shard_1')
    status, headers, response = api_logger.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                        'HTTP_HOST' => 'localhost.freshpo.com')
    assert_equal 200, status
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_ACCOUNT_ID].present?
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_SHARD].present?
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_USER_ID].present?
  ensure
    Middleware::ApplicationLogger.any_instance.unstub(:controller_log_info)
  end

  def test_application_logger_empty_tenant
    test_app   = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    api_logger = Middleware::ApplicationLogger.new(test_app)
    status, headers, response = api_logger.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                        'HTTP_HOST' => 'localhost.freshpo.com')
    assert_equal 200, status
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_ACCOUNT_ID].blank?
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_SHARD].blank?
    assert_equal true, headers[Middleware::ApplicationLogger::X_FD_USER_ID].blank?
  end
end
