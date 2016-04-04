require 'spec_helper'

RSpec.describe Admin::SecurityController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.whitelisted_ips.create
    currency = Subscription::Currency.find_by_name "USD"
    @account.subscription.currency = currency
    @account.subscription.save
  end

  before(:each) do
    @request.env['CLIENT_IP'] = "127.0.0.1"
    login_admin
    Delayed::Job.destroy_all
  end

  it "should load index page" do
    get :index
    response.body.should =~ /Security/
  end

  it "should not update" do
    put :update, :id => @account.id, :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => "", :logout_url => ""},
      :ssl_enabled => "0",
      :whitelisted_ip_attributes => { :enabled => "1", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", 
                                                      "end_ip"=>"127.0.0.1"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.sso_enabled.should_not eql(1)
    response.body.should =~ /Please provide a valid login url/
  end

  it "should request custom ssl" do
    post :request_custom_ssl, :domain_name => "abc.xyz.com"
  end

  it "should create whitelisted ips" do
    put :update, :id => @account.id, :account => {
      :sso_enabled => "0",
      :sso_options => { :login_url => "", :logout_url => ""},
      :ssl_enabled => "0",
      :whitelisted_ip_attributes => { :enabled => "1", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", 
                                                      "end_ip"=>"127.0.0.1"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.1"}])
    Delayed::Job.last.handler.should include("#{@account.name}: New IP restrictions have been added in your helpdesk")
  end

  it "should update trusted ips" do
    login_url = Faker::Internet.url
    logout_url = Faker::Internet.url
    put :update, :id => @account.id, :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => login_url, :logout_url => logout_url},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "1", 
                                      :id => "#{@account.whitelisted_ip.id}", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.sso_enabled.should eql(true)
    @account.ssl_enabled.should eql(true)
    @account.sso_options.should eql({ "login_url" => login_url, 
                                    "logout_url" => logout_url, 
                                    "sso_type"=>"simple" })
    @account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}])
    Delayed::Job.last.handler.should include("#{@account.name}: The IP restrictions in your helpdesk has been modified")
  end

  it "should disable trusted ips" do
    login_url = Faker::Internet.url
    logout_url = Faker::Internet.url
    put :update, :id => @account.id, :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => login_url, :logout_url => logout_url},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "0", 
                                      :id => "#{@account.whitelisted_ip.id}", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.sso_enabled.should eql(true)
    @account.ssl_enabled.should eql(true)
    @account.sso_options.should eql({ "login_url" => login_url, 
                                     "logout_url" => logout_url, 
                                     "sso_type"=>"simple" })
    @account.whitelisted_ip.ip_ranges.should eql([{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}])
    Delayed::Job.last.handler.should include("#{@account.name}: The IP restrictions in your helpdesk has been modified")
  end

  # Keep the below two test cases at the last
  it "should update ssl_type as default ssl" do
    @account.main_portal.update_attributes(:ssl_enabled => true, :elb_dns_name => "abc.qwerty.com")
    put :update, :id => @account.id, :ssl_type => "0",
    :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => login_url, :logout_url => logout_url},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "1", 
                                      :id => "#{@account.whitelisted_ip.id}", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.main_portal.ssl_enabled.should eql(false)
  end

  it "should update ssl_type as custom ssl" do
    put :update, :id => @account.id, :ssl_type => "1",
    :account => {
      :sso_enabled => "1",
      :sso_options => { :login_url => login_url, :logout_url => logout_url},
      :ssl_enabled => "1",
      :whitelisted_ip_attributes => { :enabled => "1", 
                                      :id => "#{@account.whitelisted_ip.id}", 
                                      :applies_only_to_agents => "1", 
                                      :ip_ranges => [{"start_ip"=>"127.0.0.1", "end_ip"=>"127.0.0.10"}]},
      :account_configuration_attributes => [Faker::Internet.email]
    }
    @account.reload
    @account.main_portal.ssl_enabled.should eql(true)
  end
end
