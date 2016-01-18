require 'spec_helper'

describe Search::V2::AutocompleteController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    setup_searchv2
  end

  before(:each) do
    log_in(@agent)
    request.env["HTTP_ACCEPT"] = 'application/json'
  end

  after(:all) do
    teardown_searchv2
  end

  ########################
  # Requester test cases #
  ########################

  it "should return the requester matching the complete name" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the partial name" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the complete email" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the partial email" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').first

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the email domain" do
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').last

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  it "should return the requester matching the phone number" do
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.phone

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(user.id)
  end

  ####################
  # Agent test cases #
  ####################

  it "should return the agent matching the complete name" do
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the partial name" do
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the complete email" do
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the partial email" do
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').first

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  it "should return the agent matching the email domain" do
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').last

    res_body = JSON.parse(response.body)['results'].map { |item| item['user_id'] }
    res_body.should include(user.id)
  end

  ######################
  # Company test cases #
  ######################

  it "should return the company matching complete name" do
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(company.id)
  end

  it "should return the company matching partial name" do
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.name[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(company.id)
  end

  ######################
  # Tag test cases #
  ######################

  it "should return the tag matching complete name" do
    tag = @account.tags.create(name: 'es-v2.testing1')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tags, :q => tag.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['value'] }
    res_body.should include(tag.name)
  end

  it "should return the tag matching partial name" do
    tag = @account.tags.create(name: 'es-v2.testing2')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tags, :q => tag.name[0..5]

    res_body = JSON.parse(response.body)['results'].map { |item| item['value'] }
    res_body.should include(tag.name)
  end
end