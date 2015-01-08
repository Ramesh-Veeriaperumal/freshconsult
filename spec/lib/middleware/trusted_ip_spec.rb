require 'spec_helper'

RSpec.describe Middleware::TrustedIp do
  self.use_transactional_fixtures = false

  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end

  def create_whitelisted_ips(agent_only = false)
    WhitelistedIp.destroy_all
    @account.make_current
    @account.reload
    wip = @account.build_whitelisted_ip
    wip.load_ip_info("127.0.0.1")
    wip.update_attributes({"enabled"=>true, "applies_only_to_agents"=>agent_only, 
      "ip_ranges"=>[{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]})
  end

  it 'should render ok and allow request for skipped domains' do
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    trusted_ip = Middleware::TrustedIp.new(test_app)
    status, headers, response = trusted_ip.call env_for('http://admin.freshdesk.com', {'HTTP_HOST' => 'admin.freshdesk.com'})
    status.should eql 200
  end

  it 'should render ok and allow request if shard not found' do
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    trusted_ip = Middleware::TrustedIp.new(test_app)
    status, headers, response = trusted_ip.call env_for('http://admin.freshdesk.com', {'HTTP_HOST' => 'randomaccount'})
    status.should eql 200
  end

  it 'should not allow requests from a non-whitelisted IP' do
    test_app = lambda { |env| [200, {'HTTP_HOST' => @account.full_domain}, ['OK']] }
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    trusted_ip = Middleware::TrustedIp.new(test_app)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    
    status, headers, response = trusted_ip.call env_for('http://admin.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain, 'CLIENT_IP' => '127.0.1.1', 
        'rack.session' => {'user_credentials_id' => "abcdef"} })
    status.should eql 302
  end

  it 'should not allow requests for a customer when requested from non-whitelisted IP' do
    test_app = lambda { |env| [200, {'HTTP_HOST' => @account.full_domain}, ['OK']] }
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    trusted_ip = Middleware::TrustedIp.new(test_app)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    
    status, headers, response = trusted_ip.call env_for('http://admin.freshdesk.com', 
      { 'HTTP_HOST' => @account.full_domain, 'CLIENT_IP' => '127.0.1.1', 
        'rack.session' => {'user_credentials_id' => @customer.id} })
    status.should eql 200
  end
end