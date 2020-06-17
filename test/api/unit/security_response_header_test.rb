require_relative '../../test_helper'
class SecurityResponseHeaderTest < ActionView::TestCase
  def env_for(url, opts = {})
    Rack::MockRequest.env_for(url, opts)
  end

  def test_content_type_options_header_present
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    security_response_header = Middleware::SecurityResponseHeader.new(test_app)
    status, headers, response = security_response_header.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories',
                                                        'HTTP_HOST' => 'localhost.freshpo.com',
                                                        'PATH_INFO' => '/tickets_list')
    assert_equal 200, status
    assert_equal true, headers['X-Content-Type-Options'].present?
  end

  def test_content_type_options_header_signup_page
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'localhost' }, ['OK']] }
    security_response_header = Middleware::SecurityResponseHeader.new(test_app)
    status, headers, response = security_response_header.call env_for('http://localhost.freshpo.com/api/v2/new_signup_free',
                                                        'HTTP_HOST' => 'localhost.freshpo.com',
                                                        'PATH_INFO' => '/new_signup_free')
    assert_equal 200, status
    assert_equal true, headers['X-Content-Type-Options'].blank?
  end
end
