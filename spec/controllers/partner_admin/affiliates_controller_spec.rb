require 'spec_helper'

# Tests may fail if test db is not in sync with Chargebee account.

describe PartnerAdmin::AffiliatesController do
  self.use_transactional_fixtures = false
  user_name = AppConfig["reseller_portal"]["user_name"]
  password = AppConfig["reseller_portal"]["password"]
  shared_secret = AppConfig["reseller_portal"]["shared_secret"]
  reseller_token = "FDRES2"
  
  before(:each) do    
    timestamp = Time.now.getutc.to_i.to_s
    digest  = OpenSSL::Digest.new('MD5')
    hash = OpenSSL::HMAC.hexdigest(digest, shared_secret, user_name+timestamp)
    @auth_params = { :hash => hash, :timestamp => timestamp }

    @request.host = "partner.freshpo.com"
    @request.env["HTTP_ACCEPT"] = "application/json"
    password_hash = Digest::MD5.hexdigest(password)
    @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("#{user_name}:#{password_hash}") 
  end

  #Reseller Portal API
  it "should add reseller" do      
    reseller_params = { :name => "Test Reseller", :token => reseller_token, :rate => 0.2 } 
    @request.env['RAW_POST_DATA'] = reseller_params.to_json
    post "add_reseller", reseller_params.merge!(@auth_params)
    SubscriptionAffiliate.find_by_token(reseller_token).should be_present
  end

  it "should add subscriptions to reseller" do
    domain = Account.first.full_domain
    params = { :token => reseller_token, :domains => [ domain ] }
    @request.env['RAW_POST_DATA'] = params.to_json
    post "add_subscriptions_to_reseller", params.merge!(@auth_params)

    account = Account.find_by_full_domain(domain)
    reseller = SubscriptionAffiliate.find_by_token(reseller_token)
    response.status.should eql(200)
    reseller.subscriptions.should include account.subscription
  end

  it "should fetch affiliate subscriptions" do
    reseller_params = { :token => reseller_token, :state => "trial", :page => 1 } 
    @request.env['RAW_POST_DATA'] = Base64.encode64(reseller_params.to_json)
    get "fetch_affilate_subscriptions", reseller_params.merge!(@auth_params)
    response.status.should eql(200)
  end

  it "should get reseller account summary" do
    reseller_params = { :token => reseller_token } 
    @request.env['RAW_POST_DATA'] = Base64.encode64(reseller_params.to_json)
    get "affiliate_subscription_summary", reseller_params.merge!(@auth_params)
    response.status.should eql(200)    
  end

  it "should fetch reseller account info" do
    reseller_params = { :account_id => 1 } 
    @request.env['RAW_POST_DATA'] = Base64.encode64(reseller_params.to_json)
    get "fetch_reseller_account_info", reseller_params.merge!(@auth_params)
    response.status.should eql(200)    
  end

  it "should fetch reseller account activity" do
    reseller_params = { :id => 1 } 
    @request.env['RAW_POST_DATA'] = Base64.encode64(reseller_params.to_json)
    get "fetch_account_activity", reseller_params.merge!(@auth_params)
    response.status.should eql(200)    
  end

  it "should fetch remove reseller subscription" do
    reseller_params = { :account_id => 1 } 
    @request.env['RAW_POST_DATA'] = reseller_params.to_json
    post "remove_reseller_subscription", reseller_params.merge!(@auth_params)
    response.status.should eql(200)    
  end

  #Share A Sale API
  # it "should add account to shareasale" do
  #   reseller_params = { :tracking => Account.first.full_domain, :userID => "123", :commission => 0.2, 
  #                         :transID => "123", :amount => 50 } 
  #   @request.env['RAW_POST_DATA'] = reseller_params.to_json
  #   @request.env['HTTPS'] = 'on'

  #   post "add_affiliate_transaction", reseller_params
    
  #   response.status.should eql(200)    
  # end
end
