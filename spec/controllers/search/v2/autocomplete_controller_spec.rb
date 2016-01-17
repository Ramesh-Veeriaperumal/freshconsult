require 'spec_helper'

describe Search::V2::AutocompleteController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Searchv2::TestCluster.start
    Sidekiq::Testing.inline!

    @account.features.es_v2_writes.create
    @account.send(:enable_searchv2)
  end

  before(:each) do
    log_in(@agent)
    request.env["HTTP_ACCEPT"] = 'application/json'
  end

  after(:all) do
    @account.send(:disable_searchv2)
    Searchv2::TestCluster.stop
  end

  ########################
  # Requester test cases #
  ########################

  it "should return the requester matching the complete name" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the partial name" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the complete email" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the partial email" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').first

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the email domain" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').last

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the phone number" do
    user = add_new_user_without_email(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.phone

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  ####################
  # Agent test cases #
  ####################

  it "should return the agent matching the complete name" do
    user = add_test_agent(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the partial name" do
    user = add_test_agent(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the complete email" do
    user = add_test_agent(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the partial email" do
    user = add_test_agent(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').first

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the email domain" do
    user = add_test_agent(@account)
    sleep 3 # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').last

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  ######################
  # Company test cases #
  ######################

  it "should return the company matching complete name" do
    company = create_company
    sleep 3 # Delaying for sidekiq to send to ES

    get :companies, :q => company.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(company.id)
  end

  it "should return the company matching partial name" do
    company = create_company
    sleep 3 # Delaying for sidekiq to send to ES

    get :companies, :q => company.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(company.id)
  end
end