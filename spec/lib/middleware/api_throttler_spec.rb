require 'spec_helper'

RSpec.describe Middleware::ApiThrottler do
  include Redis::RedisKeys
  include Redis::OthersRedis
  self.use_transactional_fixtures = false

  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end

  it 'should not throttle restricted domains' do
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://admin.freshdesk.com', {'HTTP_HOST' => 'admin.freshdesk.com'})
    status.should eql 200
  end

  it 'should allow api request and increment current request count in redis' do
    key = Redis::RedisKeys::API_THROTTLER % {:host => @account.full_domain}
    remove_others_redis_key key
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://admin.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain, 'HTTP_USER_AGENT' => 'curl/7.43.0', 'REQUEST_URI' => 'http://example.freshdesk.com/helpdesk/tickets', 'CONTENT_TYPE' => 'application/json' })
    get_others_redis_key(key).to_i.should >= 1
    status.should eql 200
  end

  it 'should allow api request with content_type and increment current request count in redis' do
    key = Redis::RedisKeys::API_THROTTLER % {:host => @account.full_domain}
    remove_others_redis_key key
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://example.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain, 'HTTP_USER_AGENT' => 'curl/7.43.0', 'REQUEST_URI' => 'http://example.freshdesk.com/helpdesk/tickets', 'CONTENT_TYPE' => 'application/json' })
    get_others_redis_key(key).to_i.should >= 1
    status.should eql 200
  end

  it 'should allow api request with user_agent as Freshdesk_Native and does not increment current request count in redis' do
    key = Redis::RedisKeys::API_THROTTLER % {:host => @account.full_domain}
    remove_others_redis_key key
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://example.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain,'HTTP_USER_AGENT' => 'Freshdesk_Native', 'REQUEST_URI' => 'http://example.freshdesk.com/helpdesk/tickets', 'CONTENT_TYPE' => 'application/json; charset=UTF-8' })
    get_others_redis_key(key).to_i.should == 0
    status.should eql 200
  end

  it 'should allow api request with format=json and increment current request count in redis' do
    key = Redis::RedisKeys::API_THROTTLER % {:host => @account.full_domain}
    remove_others_redis_key key
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://example.freshdesk.com?format=json', 
      { 'HTTP_HOST' => @account.full_domain, 'HTTP_USER_AGENT' => 'curl/7.43.0', 'REQUEST_URI' => 'http://example.freshdesk.com/helpdesk/tickets?format=json', 'CONTENT_TYPE' => 'application/json; charset=UTF-8' })
    get_others_redis_key(key).to_i.should >= 1
    status.should eql 200
  end

  it 'should not allow api request if request count exceeds 1000' do
    key = Redis::RedisKeys::API_THROTTLER % {:host => @account.full_domain}
    remove_others_redis_key key
    set_others_redis_key key, 2000
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    api_throttler = Middleware::ApiThrottler.new(test_app)
    status, headers, response = api_throttler.call env_for('http://admin.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain, 'HTTP_USER_AGENT' => 'curl/7.43.0', 'REQUEST_URI' => 'http://example.freshdesk.com/helpdesk/tickets?format=json', 'CONTENT_TYPE' => 'application/json' })
    status.should eql 403
  end

end