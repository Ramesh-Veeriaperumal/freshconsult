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

  it "should not fetch ticket by display ID that begins with original display ID" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => "#{ticket.display_id}#{Random.rand(0..9)}"

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end

  it "should not fetch ticket by another display ID" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => Random.rand.to_s[2..6]

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end

  it "should not fetch ticket by random subject" do
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject.reverse

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end

  it "should not fetch ticket by requester's name reversed" do
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.name.reverse

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end

  it "should not fetch ticket by requester's email reversed" do
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.email.reverse

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end

  it "should not fetch ticket by requester's phone number reversed" do
    requester = add_new_user_without_email(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.phone.reverse

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(ticket.id)
  end
end