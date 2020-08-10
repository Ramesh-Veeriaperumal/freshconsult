require_relative '../unit_test_helper'

class PodRedirectTest < ActionView::TestCase

  def test_request_redirection
    test_app = ->(env) { [200, { 'HTTP_HOST' => 'testaccount.freshdesk.com' }, ['OK']] }
    pod_name = Faker::Lorem.characters(10)
    stub_shard_mapping(pod_name)
    result = Middleware::PodRedirect.new(test_app).call Rack::MockRequest.env_for('https://testaccount.freshdesk.com')
    assert_equal result[1]['X-Accel-Redirect'], "@pod_redirect_#{pod_name}"
  ensure
    ShardMapping.unstub(:lookup_with_domain)
  end

  def test_forwared_request_at_actual_pod
    test_app = ->(env) { [200, env.merge('HTTP_HOST': 'testaccount.freshdesk.com'), ['OK']] }
    call_mock = Rack::MockRequest.env_for('https://testaccount.freshdesk.com', 'HTTP_X_REAL_IP' => '123.4.534.54', 'HTTP_X_SECRET_TOKEN_FD_POD_REDIRECT' => '002803199700') # adding a random value for 'HTTP_X_SECRET_TOKEN_FD_POD_REDIRECT' as we are only checking for presence
    result = Middleware::PodRedirect.new(test_app).call(call_mock)
    assert_equal result[1]['HTTP_X_FORWARDED_FOR'], '123.4.534.54'
    assert_equal result[1]['REMOTE_ADDR'], '123.4.534.54'
    assert_equal result[1]['CLIENT_IP'], '123.4.534.54'
  end

  def test_request_to_correct_pod
    test_app = ->(env) { [200, env.merge('HTTP_HOST': 'testaccount.freshdesk.com'), ['OK']] }
    stub_shard_mapping(PodConfig['CURRENT_POD'])
    result = Middleware::PodRedirect.new(test_app).call Rack::MockRequest.env_for('https://testaccount.freshdesk.com')
    assert_equal nil, result[1]['HTTP_X_FORWARDED_FOR']
    assert_equal 200, result[0]
  ensure
    ShardMapping.unstub(:lookup_with_domain)
  end

  def stub_shard_mapping(pod_info)
    ShardMapping.stubs(:lookup_with_domain).returns(ShardMapping.new(pod_info: pod_info))
  end
end
