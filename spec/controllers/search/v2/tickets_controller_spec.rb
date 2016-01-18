require 'spec_helper'

describe Search::V2::TicketsController do
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

  it "should fetch ticket by complete display ID" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => ticket.display_id

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by partial display ID" do
    ticket = create_ticket({ display_id: 212200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => '212'

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by complete subject" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by partial subject" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject[0..10]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by requester's name" do
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.name

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by requester's email" do
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.email

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end

  it "should fetch ticket by requester's phone number" do
    requester = add_new_user_without_email(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.phone

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should include(ticket.id)
  end
end