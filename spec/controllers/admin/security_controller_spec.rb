require 'spec_helper'

describe Admin::SecurityController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.whitelisted_ips.create
  end

  before(:each) do
    @request.env['CLIENT_IP'] = "127.0.0.1"
    login_admin
    # Delayed::Job.destroy_all
  end

  it "should create whitelisted ips" do
    put :update, :id => @account.id, :account => {
      :sso_enabled => "0",
      :sso_options => { :login_url => "", :logout_url => ""},
      :ssl_enabled => "0",
      :whitelisted_ip_attributes => { :enabled => "1", :applies_only_to_agents => "1", :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.1"}]},
      :account_configuration_attributes => ["bharath.kumar@freshdesk.com"]
    }
    @account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.1"}])
    # Delayed::Job.last.handler.should include("New IP restrictions have been added in your helpdesk")
  end

  it "should update trusted ips" do
    put :update, :id => @account.id, :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => "test.test.com/login", :logout_url => "test.test.com/logout"},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "1", :id => "#{@account.whitelisted_ip.id}", :applies_only_to_agents => "1", :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => ["bharath.kumar@freshdesk.com"]
    }
    account = Account.find_by_id(@account.id)
    account.sso_enabled.should eql(true)
    account.ssl_enabled.should eql(true)
    account.sso_options.should eql({ "login_url" => "test.test.com/login", "logout_url" => "test.test.com/logout", "sso_type"=>"simple" })
    account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}])
    # Delayed::Job.last.handler.should include("The IP restrictions in your helpdesk has been modified")
  end

  it "should disable trusted ips" do
    put :update, :id => @account.id, :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => "test.test.com/login", :logout_url => "test.test.com/logout"},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "0", :id => "#{@account.whitelisted_ip.id}", :applies_only_to_agents => "1", :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => ["bharath.kumar@freshdesk.com"]
    }
    account = Account.find_by_id(@account.id)
    account.sso_enabled.should eql(true)
    account.ssl_enabled.should eql(true)
    account.sso_options.should eql({ "login_url" => "test.test.com/login", "logout_url" => "test.test.com/logout", "sso_type"=>"simple" })
    account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}])
    # Delayed::Job.last.handler.should include("The IP restrictions in your helpdesk has been modified")
  end

end
