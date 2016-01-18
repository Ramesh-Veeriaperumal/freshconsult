require 'spec_helper'

describe Search::V2::MergeTopicsController do
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

  it "should not return the locked topic matching the title" do
    topic = create_test_topic(@account.forums.first, get_admin)
    lock_topic(topic)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :search_topics, :term => topic.title

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(topic.id)
  end

  it "should not return the locked topic matching the post content" do
    topic = create_test_topic(@account.forums.first, get_admin)
    lock_topic(topic)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :search_topics, :term => topic.posts.first.body

    res_body = JSON.parse(response.body)['results'].map { |item| item['id'] }
    res_body.should_not include(topic.id)
  end

end