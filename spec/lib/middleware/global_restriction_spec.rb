require 'spec_helper'

describe Middleware::GlobalRestriction do
  self.use_transactional_fixtures = false

  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end

  it 'should restrict restricted IP' do
    global_blacklist_ip = GlobalBlacklistedIp.first
    global_blacklist_ip.update_attributes(:ip_list => ["127.0.0.1"])
    Rack::Request.any_instance.stubs(:ip).returns("127.0.0.1")
    test_app = lambda { |env| [200, {}, ['OK']] }
    api_throttler = Middleware::GlobalRestriction.new(test_app)
    status, headers, response = api_throttler.call env_for('http://test.freshdesk.com')
    status.should eql 302
  end
end